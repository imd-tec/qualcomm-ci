#!/usr/bin/env python3
"""De-mosaic a SGRBG10-packed raw frame from the AR1335 into a PNG.

Sensor: AR1335 on QCS8550-IMDT-SBC
Format: V4L2_PIX_FMT_SGRBG10P  (pgAA)
  - Bayer pattern: GR / BG (GRBG)
  - Packing: MIPI RAW10 — 4 pixels per 5 bytes
      byte[0] = P0[9:2]   byte[1] = P1[9:2]
      byte[2] = P2[9:2]   byte[3] = P3[9:2]
      byte[4] = P3[1:0] P2[1:0] P1[1:0] P0[1:0]
"""

import argparse
import sys
import cv2
import numpy as np
from PIL import Image

# Sensor defaults — overridable via CLI
_W   = 4208
_H   = 3120
_BPL = 5264   # bytes per line (includes 4 bytes padding per row)


def unpack_sgrbg10p(data: bytes, width: int, height: int, bpl: int) -> np.ndarray:
    """Unpack MIPI RAW10 bytes → uint16 array shape (height, width)."""
    raw = np.frombuffer(data, dtype=np.uint8)
    groups = width // 4
    active = groups * 5          # active bytes per row (no padding)

    row_starts  = np.arange(height, dtype=np.int32) * bpl
    col_offsets = np.arange(active, dtype=np.int32)
    indices     = row_starts[:, None] + col_offsets[None, :]
    rows        = raw[indices].reshape(height, groups, 5)

    msb = rows[:, :, :4].astype(np.uint16)
    lsb = rows[:, :, 4].astype(np.uint16)

    p = msb << 2
    p[:, :, 0] |=  lsb        & 0x03
    p[:, :, 1] |= (lsb >> 2)  & 0x03
    p[:, :, 2] |= (lsb >> 4)  & 0x03
    p[:, :, 3] |= (lsb >> 6)  & 0x03

    return p.reshape(height, width)


def demosaic(bayer: np.ndarray) -> np.ndarray:
    """Bilinear Bayer demosaic for GRBG → uint8 RGB (H, W, 3)."""
    # Demosaic straight to RGB order, then keep a single float32 RGB buffer.
    rgb = cv2.cvtColor(bayer.astype(np.uint16), cv2.COLOR_BAYER_GR2RGB)
    rgb = rgb.astype(np.float32)

    # Gray-world white balance — scale R and B channels in place.
    g_mean = rgb[:, :, 1].mean()
    r_mean = rgb[:, :, 0].mean()
    b_mean = rgb[:, :, 2].mean()
    if r_mean > 0:
        rgb[:, :, 0] *= g_mean / r_mean
    if b_mean > 0:
        rgb[:, :, 2] *= g_mean / b_mean

    # Percentile stretch: map p1–p99 → 0–255. The reshape is a view on the
    # contiguous RGB buffer, so percentiles cost no extra full-resolution copy.
    lo, hi = np.percentile(rgb.reshape(-1), (1, 99))
    if hi <= lo:
        hi = lo + 1.0

    rgb -= lo
    rgb *= 255.0 / (hi - lo)
    np.clip(rgb, 0, 255, out=rgb)
    return rgb.astype(np.uint8)


def main():
    ap = argparse.ArgumentParser(description='De-mosaic AR1335 SGRBG10P raw → PNG')
    ap.add_argument('input',                                       help='Raw input file')
    ap.add_argument('output',                                      help='PNG output file')
    ap.add_argument('--width',    type=int, default=_W,            help='Sensor width  (default %(default)s)')
    ap.add_argument('--height',   type=int, default=_H,            help='Sensor height (default %(default)s)')
    ap.add_argument('--bpl',      type=int, default=_BPL,          help='Bytes per line (default %(default)s)')
    ap.add_argument('--out-size', type=str, default='0x0',
                    help='Resize output to WxH with Lanczos (default 0x0 = no resize)')
    args = ap.parse_args()

    out_w, out_h = (int(v) for v in args.out_size.lower().split('x'))

    print(f'Reading {args.input} ({args.width}×{args.height}, bpl={args.bpl})', flush=True)
    with open(args.input, 'rb') as f:
        data = f.read()

    frame_size = args.bpl * args.height
    n_frames = len(data) // frame_size
    if n_frames > 1:
        print(f'Multi-frame file ({n_frames} frames) — using last frame', flush=True)
        data = data[-frame_size:]
    elif len(data) < frame_size:
        print(f'Warning: file is {len(data)} bytes, expected {frame_size}', file=sys.stderr)

    bayer = unpack_sgrbg10p(data, args.width, args.height, args.bpl)
    print('Demosaicing…', flush=True)
    rgb = demosaic(bayer)

    img = Image.fromarray(rgb, 'RGB')
    if out_w and out_h:
        img = img.resize((out_w, out_h), Image.LANCZOS)
    img.save(args.output)
    print(f'Wrote {args.output} ({img.width}×{img.height})', flush=True)


if __name__ == '__main__':
    main()
