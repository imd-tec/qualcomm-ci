# QUALCOMM BUILD AUTOMATION WIP

Aims to automate build process for Qualcomm-based builds. Adapted from getting started guides. The build process is executed under /mnt/nvm1/qcom_ci/builds/<project>/<sub-project>/<version>/.

**Requirements**
- Qualcomm manifest repository containing trigger-build.yml under *.github/workflows*
-   There must be a single yml file located in a manifest directory, outlining the build details for each manifest version. See *config_example.yml* for a template. Each key is strictly required.
- QCI_DEPLOY_KEY, located in this repository under *Settings/Deploy_keys*, must be assigned as a secret in the aforemnetioned external repository to access scripts located on this repository.
  
**How it works:**
1. A manifest change push or cron job (for dev builds) triggers a workflow on the given manifest repository.
2. The calling workflow fetches the corresponding build details for the given manifest/s from the configuration yaml located in the same repository.
3. These details are passed to the reusable workflow located in the *qualcomm-ci* via the *workflow_call* keyword.
4. The reusable workflow executes the corresponding build steps, as per the getting started guide manual build process, applying the build details specified in the configuration yaml.
5. The final build image is located in the corresponding build folder in /mnt/nvme1/qcom_ci/builds/. 

**Notes:**
- All referenced files are stored under */mnt/nvme1/qcom_ci/* on the qcom desktop.
- Qualcomm source files are located in */mnt/nvme1/qcom_ci/builds/SHARED_SOURCES/*
  - As it stands, Qualcomm source files will need to be manually added to the *SHARED_SOURCES* directory.
- For patches, the *HAS_PATCHES* flag must be set in the configuration for the particular build version and patches should be contained under */mnt/nvme1/qcom_ci/builds/[PROJECT]/[VERSION]/SOURCES/patches/*
  - A *download_patches.py* script can be found in */mnt/nvme1/qcom_ci/scripts/google_api/* that automates the fetching of patches from Google Drive .
    - This script assumes case-insensitive matches between Google Drive folder and manifest file names. Additional information can be found in the aforementioned directory README.
    - The script currently utilizes a personal OAUTH token for Drive access. If this script provides useful, a service account should be used instead.

