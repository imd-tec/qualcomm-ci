# QUALCOMM BUILD AUTOMATION

Aims to automate fetching of sources and build process for Qualcomm-based build. This process is adapted from Qualcomm Getting Started guides. The build process is executed in, and the resulting artifacts can be found at /mnt/nvm1/qcom_ci/builds/[project]/[sub-project]/[version]/. 

**Requirements**
- A Qualcomm manifest repository that
  - Contains the *trigger-build.yml* workflow under *.github/workflows*. This can be found in *for-manifest-repo/*.
  - Has a PAT secret for inter-repo read access.
  - Has a single yml configuration file located at the same depth as the *manifest.xml* files, which outlines the build details for each manifest version. See *for-manifest-repo/config_example.yml* for a template.
- The *imdt-qcom-desktop* self-hosted runner must be shared to the repository.

**How it works:**
1. A push affecting (or creating) a manifest file triggers *trigger-build.yml* on the manifest repository. Alternatively, cron-jobs can trigger scheduled development builds (**WIP**) and manual dispatch (under the *Actions* tab) can trigger specified builds (check DEBUG_LIST, provided BUILD_DEBUG is set to "1" in *trigger-build.yml*).
2. The triggered workflow fetches the corresponding build details for the given changed manifest/s. These details are extracted from the aforementioned configuration yaml.
3. Each set of details are then iterated over and passed to the reusable build workflow located in the *qualcomm-ci* via the *workflow_call* keyword.
4. Upon receiving a set of details, the reusable workflow executes the build steps, broadly following the Getting Started build process. This continues until all triggered builds either complete, fail or are manually cancelled.
5. The final build artifact is located in the corresponding build folder under /mnt/nvme1/qcom_ci/builds/. 

**Notes:**
- This currently depends on a personal PAT for inter-repository access and should later be adapted to a service account or other user account independent token.
- All referenced files are stored under */mnt/nvme1/qcom_ci/* on the qcom desktop.
- Qualcomm source files are located in */mnt/nvme1/qcom_ci/builds/SHARED_SOURCES/*
  - As it stands, Qualcomm source files will need to be manually added to the *SHARED_SOURCES* directory.
- [**To be changed**] For patches, the *HAS_PATCHES* flag must be set in the configuration for the particular build version and patches should be contained under */mnt/nvme1/qcom_ci/builds/[PROJECT]/[VERSION]/SOURCES/patches/*
  - A *download_patches.py* script can be found in */mnt/nvme1/qcom_ci/scripts/google_api/* that automates the fetching of patches from Google Drive .
    - This script assumes case-insensitive matches between Google Drive folder and manifest file names. Additional information can be found in the aforementioned directory README.
    - The script currently utilizes a personal OAUTH token for Drive access. If this script proves useful, a service account should be used instead.

