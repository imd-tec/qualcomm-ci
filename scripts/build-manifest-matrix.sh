#!/bin/bash
#=============================================================================================================================================================================
#title: build-manifest-matrix.sh
#description
#     For use exclusively within the trigger-build.yml workflow.
#     Takes in newline separated manifest file names in previously created $RUNNER_TEMP/manifest.txt and extracts each files corresponding build details from the yaml configuration file.
#     Outputs Json array of each manifest and its respective build details to $GITHUB_OUTPUT.
#     Additionally creates a $GITHUB_STEP_SUMMARY table for viewing triggered build details on workflow execution.
#usage: 
#     build_manifest_matrix.sh --manifest_list <line_separated_list_of_manifests> --manifest_path <path_to_manifest_repo_root> 
#outputs:
#     manifest_list: single-line JSON array of manifest build details
#     count: number of manifests processed
#=============================================================================================================================================================================

set -e

#set default input path to $RUNNER_TEMP/manifests.txt and default root path to current directory
MANI_LIST="${RUNNER_TEMP}/manifests.txt"
MANI_REPO_PATH="."

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--manifest_list)
        MANI_LIST="$2"; shift 2 ;;
      -p|--manifest_path)
        MANI_REPO_PATH="$2"; shift 2 ;;
      *)
        echo "Unknown option: $1"; exit 1 ;;
    esac
  done
}

function construct_manifest_json() {
  #STEP SUMMARY: creates build details header for Github Action step summary
  {
      echo "## Triggered Builds"
      echo ""
      echo "| Manifest | Name | Version | Kernel Variant | Distro | Machine | Image | Docker | Release Name | Pyenv | QCS Sources | Patch Script Path | Skip Steps |"
      echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
  } >> "$GITHUB_STEP_SUMMARY"


  #read in manifests from input file into array
  mapfile -t MANIFESTS < "$MANI_LIST"
  echo "Processing ${#MANIFESTS[@]} manifest(s)..."

  JSON='[]'

  #for each manifest file, access the corresponding project config yaml and extract build details
  for manifest_path in "${MANIFESTS[@]}"; do

      #get path to manifest file
      full_path="${MANI_REPO_PATH}/${manifest_path}"
      echo "Processing: $manifest_path ($full_path)"
      
      #derive config file path (stored in same directory as manifest) from manifest path
      mani_dir="$(dirname "$full_path")"
      echo "Looking for build configuration details in in $mani_dir"
      config_file="$(find "$mani_dir" -maxdepth 1 -type f -name '*.yml')"

      #ensure that there is only one config file
      lines=$(echo "$config_file" | wc -l)
      if [ "$lines" -gt 1 ]; then
        echo "Error: More than one YAML config file found in $mani_dir. Please ensure only one config file is present."
      exit 1
      elif [ -z "$config_file" ]; then
        echo -e "Error: No YAML config file found in directory $mani_dir.\nPlease ensure a config file is present. See Qualcomm CI documentation for more details."
      exit 1
      fi

      echo -e "One configuration file found.\nUsing config file: $config_file"

      #extract manifest name from project path to access config details
      manifest_name=$(basename "$manifest_path" .xml)
      echo "Processing manifest: $manifest_name"

      #if a corresponding manifest key is not found in the config yaml, echo result tostep summary and continue to next manifest
      if ! yq -e 'has("'"$manifest_name"'")' "$config_file" >/dev/null; then
        echo "| \`$manifest_path \` | \`No Key Found: check $config_file\` |" >> "$GITHUB_STEP_SUMMARY"
        continue
      fi

      #if manifest key is 'development', echo result to step summary and continue to next manifest
      if [ "$manifest_name" = "development" ] && [ "$GITHUB_EVENT_NAME" = 'push' ]; then
        echo "| \`$manifest_path \` | \`Skipped: development manifest\` |" >> "$GITHUB_STEP_SUMMARY"
        continue
      fi

      #ACCESS YAML CONFIGURATION DETAILS
      # e.g., machine: "imsu-glasses-poc"
      machine=$(yq '."'"${manifest_name}"'".machine' "$config_file") 

      # e.g., version: "1.0.0"
      version=$(yq '."'"${manifest_name}"'".version' "$config_file")

      # e.g., kernel_variant  : "consolidate" or "gki"
      kernel_variant=$(yq '."'"${manifest_name}"'".kernel_variant' "$config_file")

      # e.g., distro: "imdt-qcom-distro-perf"
      distro=$(yq '."'"${manifest_name}"'".distro' "$config_file")

      # e.g., image: "imdt-glasses-image-weston"
      image=$(yq '."'"${manifest_name}"'".image' "$config_file")

      # e.g., docker: "imdtec/imdt-qualcomm-build-setup:0.5.1"
      docker=$(yq '."'"${manifest_name}"'".docker' "$config_file")

      # e.g., release_name: "imsu_glasses_prebuilt_release_v1.0.0"
      release_name=$(yq '."'"${manifest_name}"'".release_name' "$config_file")

      # e.g., patch_script_path: "./poky/meta-imsu-glasses/tools" or "null"
      patch_script_path=$(yq '."'"${manifest_name}"'".patch_script_path' "$config_file")

      # e.g., pyenv: "3.8.16"
      pyenv=$(yq '."'"${manifest_name}"'".pyenv' "$config_file")

      # e.g., qcs_sources: "qcs8550-le-1-0_amss_standard_oem_apqgps"
      qcs_sources=$(yq '."'"${manifest_name}"'".qcs_sources' "$config_file")

      # e.g., skip_steps: [- sync_repos, - other_step]. Convert to comma separated string to not break step summary formatting.
      skip_steps=$(yq '."'"${manifest_name}"'".skip_steps | join(", ")' "$config_file")    

      #append manifest and corresponding details to the JSON array
      JSON="$(jq -n \
      --arg manifest "$manifest_path" \
      --arg name "$manifest_name" \
      --arg version "$version" \
      --arg kernel_variant "$kernel_variant" \
      --arg machine "$machine" \
      --arg distro "$distro" \
      --arg image "$image" \
      --arg docker "$docker" \
      --arg patch_script_path "$patch_script_path" \
      --arg release_name "$release_name" \
      --arg pyenv "$pyenv" \
      --arg qcs_sources "$qcs_sources" \
      --arg skip_steps "$skip_steps" \
      --argjson arr "$JSON" \
      '$arr + [{manifest:$manifest, name:$name, version:$version, kernel_variant:$kernel_variant, distro:$distro, 
      machine:$machine, image:$image, docker:$docker, patch_script_path:$patch_script_path,
      release_name:$release_name, pyenv:$pyenv, qcs_sources:$qcs_sources, skip_steps:$skip_steps }]'
      )"

      #append results to step summary
      echo "| \`$manifest_path\` | \`$manifest_name\` | \`$version\` | \`$kernel_variant\` | \`$distro\` | \`$machine\` | \`$image\` | \`$docker\`| \`$release_name\` | \`$pyenv\` | \`$qcs_sources\` | \`$patch_script_path\` | \`$skip_steps\` |" >> "$GITHUB_STEP_SUMMARY"
      done

  #compact newly created JSON to one line, as GitHub output expects 
  compact="$(jq -c '.' <<<"$JSON")"   
}


parse_args "$@"
construct_manifest_json

#output results to GitHub Action outputs
echo "manifest_list=$compact" >> "$GITHUB_OUTPUT"
echo "count=$(jq -r 'length' <<<"$JSON")" >> "$GITHUB_OUTPUT"


