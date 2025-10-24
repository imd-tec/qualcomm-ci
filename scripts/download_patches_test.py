import runpy
import sys
import unittest
import tempfile
import os
import warnings

# Suppress SSL resource warnings during testing
warnings.filterwarnings("ignore", category=ResourceWarning)

# Map of first-argument values to whether a patch is expected to be created/found
# Set True for inputs that should produce a patch file in the destdir, False otherwise.
INPUTS = {
    # 'imdt-qcom-bsp-v1.0.0': 0,
    'imdt-qcom-bsp-v1.0.1': 1, # patch
    'imdt-qcom-bsp-v1.1.0': 1, # patch
    'imsu-microscope-bsp-v1.1.1': 1, # patch
    'imsu-microscope-bsp-v1.1.0': 1,
    'imsu-microscope-bsp-v1.2.0': 1, # patch
    'imsu-glasses-bsp-v1.0.0': 1,
    'imsu-glasses-bsp-v1.1.0': 1, # patch
    'imsu-glasses-bsp-v1.2.0': 0,
    # 'imsu-glasses-bsp-v1.3.0': 0,
    # 'imsu-glasses-bsp-v1.4.0': 0,
    # 'imsu-glasses-bsp-v1.5.0': 0,
    # 'imsu-glasses-bsp-v3.2.0': 0,
    # 'imsu-glasses-bsp-v3.2.1': 0,
}

SCRIPT_PATH = "download_patches.py"

class DownloadPatchesRunTest(unittest.TestCase):
    def test_runs_without_error(self):
        for first_arg, expects_patch in INPUTS.items():
            with self.subTest(first_arg=first_arg):
                with tempfile.TemporaryDirectory() as destdir:
                    sys.argv = ['download_patches.py', first_arg, destdir]
                    try:
                        runpy.run_path(SCRIPT_PATH, run_name='__main__')
                    except SystemExit:
                        pass
                    except Exception as exc:
                        self.fail(f"Script raised {type(exc).__name__} for arg {first_arg}: {exc}")

                    # Determine whether any regular file was created under destdir
                    found_any = 0
                    for root, _, files in os.walk(destdir):
                        os.listdir(destdir)
                        if files:
                            found_any = 1
                            for name in files:
                                p = os.path.join(root, name)
                                print(f"OUTPUT: {p}  {os.path.getsize(p)} bytes")
                            break

                    self.assertEqual(found_any, expects_patch,
                                     f"Expected patch presence={expects_patch} for '{first_arg}', found={found_any}")

if __name__ == '__main__':
    unittest.main()
