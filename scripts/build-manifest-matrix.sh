#!/usr/bin/env bash
set -euo pipefail

#For use in trigger_build.yml on external manifest repositories, see for more details.
#Takes in newline separated manifest file names in previously created $RUNNER_TEMP/manifest.txt and extracts the corresponding build details from yaml configuration file.
#Outputs Json array of each manifest and its respective build details to $GITHUB_OUTPUT.
#Additionally creates a $GITHUB_STEP_SUMMARY table for viewing triggered build details on workflow execution.
# Usage: 
# build_manifest_matrix.sh --input <line_separated_list_of_manifests>

#set default path to $RUNNER_TEMP/manifests.txt
INPUT_PATH="${RUNNER_TEMP}/manifests.txt"

#take input argument specified by -i
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)
      INPUT_PATH="${2:?missing path after $1}"
      shift 2
      ;;
  esac
done

#read in manifests from input file into array
mapfile -t MANIFESTS < "$RUNNER_TEMP/manifests.txt"

#for all manifests, extract relevant attributes and append to output JSON
JSON='[]'

#creates build details header for Github Action step summary
{
    echo "## Triggered Builds"
    echo ""
    echo "| Manifest | Name | Version | Distro | Machine | Image |  Project Path | Docker | Has Patches | Release Name | Pyenv | QCS Sources | Patch Script Path | Skip Steps |"
    echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
} >> "$GITHUB_STEP_SUMMARY"

echo "Processing ${#MANIFESTS[@]} changed manifest(s)..."


#for each manifest, access the corresponding project config yaml and extract build details
for manifest in "${MANIFESTS[@]}"; do

    #derive config file path (stored in same directory as manifest) from manifest path
    mani_dir="$(dirname "$manifest")"
    config_file="$(find "$mani_dir" -maxdepth 1 -type f -name '*.yml')"

    #verify that there is no more than one yaml file in the directory
    lines=$(echo "$config_file" | wc -l)
    if [ $lines -gt 1 ]; then
    echo "Error: More than one YAML config file found in $mani_dir"
    exit 1
    fi
    if [ -z "$config_file" ]; then
    echo "Error: No YAML config file found for $manifest in $mani_dir"
    exit 1
    fi

    #extract manifest name to access config details
    manifest_name=$(basename "$manifest" .xml) 

    #if manifest key is not found in yaml, skip to next manifest
    if ! yq -e 'has("'"$manifest_name"'")' "$config_file" >/dev/null; then
    echo "| \`$manifest \` | \`No Key Found: check $config_file\` |" >> "$GITHUB_STEP_SUMMARY"
    continue
    fi

    #if manifest key is 'development', continue to next manifest
    if [ "$manifest_name" = "development" ]; then
    echo "| \`$manifest \` | \`Skipped: development manifest\` |" >> "$GITHUB_STEP_SUMMARY"
    continue
    fi

    #access yaml config file details

    # e.g., machine: "imsu-glasses-poc"
    machine=$(yq '."'"${manifest_name}"'".machine' "$config_file") 

    # e.g., version: "1.0.0"
    version=$(yq '."'"${manifest_name}"'".version' "$config_file")

    # e.g., distro: "imdt-qcom-distro-perf"
    distro=$(yq '."'"${manifest_name}"'".distro' "$config_file")

    # e.g., image: "imdt-glasses-image-weston"
    image=$(yq '."'"${manifest_name}"'".image' "$config_file")

    # e.g., project_path: "/mnt/nvme1/qcom_ci/builds/IMSU/GLASSES/1.0.0/sources"
    project_path=$(yq '."'"${manifest_name}"'".project_path' "$config_file")

    # e.g., docker: "imdtec/imdt-qualcomm-build-setup:0.5.1"
    docker=$(yq '."'"${manifest_name}"'".docker' "$config_file")

    # e.g., release_name: "imsu_glasses_prebuilt_release_v1.0.0"
    release_name=$(yq '."'"${manifest_name}"'".release_name' "$config_file")

    # e.g., has_patches: "1"
    has_patches=$(yq '."'"${manifest_name}"'".has_patches' "$config_file")

    # e.g., patch_script_path: "./poky/meta-imsu-glasses/tools" or "null"
    patch_script_path=$(yq '."'"${manifest_name}"'".patch_script_path' "$config_file")

    # e.g., pyenv: "3.8.16"
    pyenv=$(yq '."'"${manifest_name}"'".pyenv' "$config_file")

    # e.g., qcs_sources: "qcs8550-le-1-0_amss_standard_oem_apqgps"
    qcs_sources=$(yq '."'"${manifest_name}"'".qcs_sources' "$config_file")

    # e.g., skip_steps: [- sync_repos, - other_step]
    skip_steps=$(yq '."'"${manifest_name}"'".skip_steps' "$config_file")

    #append manifest and corresponding details to the JSON array
    JSON="$(jq -n \
    --arg manifest "$manifest" \
    --arg name "$manifest_name" \
    --arg version "$version" \
    --arg machine "$machine" \
    --arg distro "$distro" \
    --arg image "$image" \
    --arg project_path "$project_path" \
    --arg docker "$docker" \
    --arg has_patches "$has_patches" \
    --arg patch_script_path "$patch_script_path" \
    --arg release_name "$release_name" \
    --arg pyenv "$pyenv" \
    --arg qcs_sources "$qcs_sources" \
    --arg skip_steps "$skip_steps" \
    --argjson arr "$JSON" \
    '$arr + [{manifest:$manifest, name:$name, version:$version, distro:$distro, 
    machine:$machine, image:$image, project_path:$project_path, docker:$docker,
    has_patches:$has_patches, patch_script_path:$patch_script_path,
    release_name:$release_name, pyenv:$pyenv, qcs_sources:$qcs_sources, skip_steps:$skip_steps }]'
    )"

    #append results to step summary
    echo "| \`$manifest\` | \`$manifest_name\` | \'$version\' | \'$distro\' | \`$machine\` | \`$image\` | \`$project_path\` | \`$docker\`| \`$has_patches\` | \`$release_name\` | \`$pyenv\` | \`$qcs_sources\` | \`$patch_script_path\` | \`$skip_steps\` |" >> "$GITHUB_STEP_SUMMARY"
    done

#compact JSON to one line and direct to Github output
compact="$(jq -c . <<<"$JSON")"
echo "manifest_list=$compact" >> "$GITHUB_OUTPUT"
echo "count=$(jq -r 'length' <<<"$JSON")" >> "$GITHUB_OUTPUT"


