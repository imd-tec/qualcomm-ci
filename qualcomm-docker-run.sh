#!/bin/bash

set -e

# Function to display usage
usage() {
    echo "Usage: $0 --container-name <name> [--usessh] [--sdk] [--swu] --manifest-repo <repo_url> --manifest-branch <branch_name> --manifest-xml <filename>"
    exit 1
}



while [[ "$#" -gt 0 ]]; do
    case $1 in
        --usessh) usessh=1 ;;
        --sdk) sdk=1 ;;
        --swu) swu=1 ;;
        --v2n) v2n=1 ;;
        --container-name) container_name="$2"; shift ;;
        --manifest-repo) manifest_repo="$2"; shift ;;
        --manifest-xml) manifest_xml="$2"; shift ;;
        --manifest-branch) manifest_branch="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate arguments
if [[ -z "$container_name" || -z "$manifest_repo" || -z "$manifest_xml" || -z "$manifest_branch" ]]; then
    echo "Error: Missing required arguments."
    usage
fi

# Display the provided arguments
echo "Using SSH: $usessh"
echo "Build SDK: $sdk"
echo "Build SWU: $swu"
echo "Build for V2N: $v2n"
echo "Container Name: $container_name"
echo "Manifest Repo: $manifest_repo"
echo "Manifest Branch: $manifest_branch"
echo "Manifest XML: $manifest_xml"
id

# # Set SSH_DIR if usessh is enabled
# if [[ "$usessh" -eq 1 ]]; then
#     echo "# Horrid .ssh permissions hack"
#     echo "# setting SSH_DIR to ~/ssh_1000 if it exists, else ~/.ssh"
#     if [ -d ~/ssh_1000 ]; then
#         SSH_DIR=~/ssh_1000
#     else
#         SSH_DIR=~/.ssh
#     fi
# fi


#CREATE THE CONTAINER
#mount sources directory and scripts netrc
docker run -d --rm \
    --name "$container_name" \
     -v "/mnt/nvme1/qcom_ci/builds/:/Qualcomm/" \
     -v "/mnt/nvme1/qcom_ci/scripts/build_netrc.sh:/home/dev/build_netrc.sh" \
    imdtec/imdt-qualcomm-build-setup:0.5.1 \
    sleep infinity


export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps.git
echo "QCOM_ROOT_DIR=$QCOM_ROOT_DIR"
ls $QCOM_ROOT_DIR
ls /home/dev/


# chmod +x for_docker/bitbake-build.sh
# bitbake_command="/workflows/bitbake-build.sh --manifest-repo ${manifest_repo} --manifest-branch ${manifest_branch} --manifest-xml ${manifest_xml} ${sdk:+--sdk} ${swu:+--swu} ${v2n:+--v2n}"


# # Run the script inside the container using docker exec with the container name
# echo "# Running the script inside the container."
# docker exec "${container_name}" /bin/bash -c "${bitbake_command}"

# # Copy the /output directory from the container to the local working_directory
# echo "# Copying the output directory from the container."
# mkdir working_directory
# docker cp "${container_name}:/home/imdt/output" "$(pwd)/working_directory"


