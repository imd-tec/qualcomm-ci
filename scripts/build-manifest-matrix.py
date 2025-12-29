"""build-manifest-matrix.py

    For use exclusively within the trigger-build.yml workflow.
    Takes in newline separated manifest file names from previously created $RUNNER_TEMP/manifests.txt and 
    extracts each files corresponding build details from the yaml configuration file.
    Outputs Json array of each manifest and its respective build details to $GITHUB_OUTPUT.
    Additionally creates a $GITHUB_STEP_SUMMARY table for viewing triggered build details on workflow execution.

    usage: 
        build-manifest-matrix.sh --manifest_list <line_separated_list_of_manifests_txt> --manifest_path <path_to_manifest_repo_root>
    
    outputs:
        manifest_list: single-line JSON array of manifest build details
"""

from argparse import ArgumentParser
import glob
import json
import os
from pathlib import Path
import sys
from typing import Any
import yaml

#fields to extract from each manifest's yaml config. Also serves as table columns in Github Actions step summary.
MANIFEST_FIELDS=["version", "kernel_variant",
        "machine", "distro", "image", "base_docker_image", "imdt_patch_script_path",
        "release_name", "pyenv", "qcs_sources", "patch_fallback_path", "skip_steps"]

STEP_SUMMARY_PATH = os.environ['GITHUB_STEP_SUMMARY']
GITHUB_OUTPUT = os.environ.get("GITHUB_OUTPUT")

def parse_args():
    arg_parser = ArgumentParser()
    arg_parser.add_argument(
        "-m",
        "--manifest_list",
        help="Path to newline separated manifest list of manifests.",
        type= Path,
        required=True,
        )
    arg_parser.add_argument(
        "-p",
        "--manifest_path",
        help="Path to the manifest repository root.",
        type= Path,
        required=True,
    )
    return arg_parser.parse_args()

def construct_step_summary_header():
    """Constructs header for the GitHub Actions step summary table."""
    headers = ["Manifest", "Name"]
    for key in MANIFEST_FIELDS:
        name = key.replace("_", " ").title()
        headers.append(f"{name}")

    header_row = "| " + " | ".join(headers) + " |" # | key1 | key2 | ... |
    separator_row = "| " + " | ".join(["---"] * len(headers)) + " |" # | --- | --- | ... |
    with open(STEP_SUMMARY_PATH, 'a') as summary_file:
        summary_file.write("## Triggered Builds\n\n")
        summary_file.write(header_row + "\n")
        summary_file.write(separator_row + "\n")

def append_to_step_summary(row_data):
    """Formats and appends a row to the summary table"""
    row = "| " + " | ".join(row_data) + " |"
    with open(STEP_SUMMARY_PATH, 'a') as summary_file:
        summary_file.write(row + "\n")        

def construct_manifest_matrix(manifest_list: Path, manifest_parent_path: Path):
    """
    Extract build details from each manifest's yaml config and constructs JSON matrix.
    Additionally constructs step summary table for Github Actions.
    """
    try: 
        with open(manifest_list, 'r') as file:
            manifests = []
            for line in file:
                line = line.strip()
                if line:
                    manifests.append(line)
    except FileNotFoundError:
        print(f"[ERROR] Manifest list file not found: {manifest_list}")
        sys.exit(1)
    
    print(f"Processing {len(manifests)} manifest(s)...")

    matrix_data = []

    for manifest_path in manifests:
        path_to_manifest = os.path.join(manifest_parent_path, manifest_path)
        manifest_directory = os.path.dirname(path_to_manifest)
        print(f"Processing manifest: {manifest_path} ({path_to_manifest})")

        #get every .yml file in the manifest directory
        yaml_files = glob.glob(os.path.join(manifest_directory, "*.yml"))

        #assert that there is exactly one yaml configuration file
        if len(yaml_files) == 0:
            print(f"[ERROR] No configuration yaml found in {manifest_directory} for manifest at {manifest_path}")
            sys.exit(1)
        elif len(yaml_files) > 1:
            print(f"[ERROR] More than one YAML config file found in {manifest_directory}. Please ensure only one config file is present.")
            sys.exit(1)
        else:
            config_file = yaml_files[0]
            print(f"Using configuration yaml: {config_file}")

        try:
            with open(config_file, 'r') as file:
                config_data = yaml.safe_load(file)
        except Exception as e:
            print(f"[ERROR] Failed to read or parse YAML file {config_file}: {e}")
            sys.exit(1)

        #extract manifest name from path 
        manifest_name, _ = os.path.splitext(os.path.basename(path_to_manifest))
        
        #find corresponding key in yaml config
        if manifest_name not in config_data:
            print(f"WARNING: No key found matching {manifest_name} in {config_file}.")
            error_row = [manifest_path, manifest_name] + ["N/A"] * len(MANIFEST_FIELDS)
            append_to_step_summary(error_row)
            continue
        
        manifest_entry: dict[str, Any] = config_data[manifest_name]

        #construct JSON for output
        manifest_json = {
                    "manifest": manifest_path,
                    "name": manifest_name
                }
        #construct step summary row
        summary_row = [manifest_path, manifest_name]

        #extract each field from those outlined in MANIFEST_FIELDS and append to JSON and summary row
        for field in MANIFEST_FIELDS:
            value = manifest_entry.get(field)

            #convert lists to comma-separated strings for summary table
            if isinstance(value, list):
                value = ", ".join(value)

            manifest_json[field] = value
            summary_row.append(value)

        matrix_data.append(manifest_json)
        append_to_step_summary(summary_row)
        print(f"Successfully extracted configuration details and added manifest '{manifest_name}' to matrix.")

    #serialise JSON and write to GITHUB_OUTPUT  
    json_output = json.dumps(matrix_data, separators=(',', ':'))
    with open(GITHUB_OUTPUT, "a") as file:
        file.write(f"manifest_list={json_output}\n")

def main() -> None:
    args = parse_args()
    construct_step_summary_header()
    construct_manifest_matrix(args.manifest_list, args.manifest_path)

if __name__ == "__main__":
    main()