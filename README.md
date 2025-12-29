# QUALCOMM BUILD AUTOMATION

Aims to automate fetching of sources and build process for Qualcomm-based builds. This process is adapted from **Qualcomm Getting Started** guides. The build process is executed in ```/mnt/nvm1/qcom_ci/builds/[project_version]/``` on **imdt-qcom-desktop**. 

The output artifacts are located in ```/mnt/nvm1/qcom_ci/builds/[project_version]/release/```.

## Requirements
**GitHub**
- A Qualcomm manifest repository that:
  - Contains the ```trigger-build.yml``` workflow under ```.github/workflows```.
    - See [```for-manifest-repo/trigger-build-ci```](https://github.com/imd-tec/qualcomm-ci/blob/master/for_manifest_repo/trigger-build-ci.yml).
  - Has a PAT secret for inter-repo read access.
  - Has a single yml configuration file located at the same depth as the manifest xml files, outlining the build details for each manifest version.
    - See [```for-manifest-repo/config_example.yml```](https://github.com/imd-tec/qualcomm-ci/blob/master/for_manifest_repo/config_example.yml) for a template.
- The ***imdt-qcom-desktop*** self-hosted runner must be shared to the manifest repository.

**Runner setup**
- For a desired build, a build directory must be located under ```/mnt/nvme1/qcom/builds/``` and must match the corresponding manifest name:

  ```imdt-qcom-bsp-v1.1.0.xml``` => ```/mnt/nvm1/qcom_ci/builds/imdt-qcom-bsp-v1.1.0```
- Must have:
  - Qualcomm source files (i.e., ```qcs8550-le-1-0_amss_standard_oem_apqgps.tar.gz```) under:
  
    ```/mnt/nvme1/qcom_ci/builds/SHARED_SOURCES/```
  - Patches archive (i.e., ```patches.tar.gz```) under:
  
    ```/mnt/nvme1/qcom_ci/builds/[project_version]/sources/```

## How it works
1. A push affecting (or creating) a manifest file triggers ```trigger-build.yml``` on the manifest repository.
   Alternatively:
     1.  Cron-jobs can trigger scheduled development builds (**To be implemented**)
     2.  Manual dispatch (under the **Actions** tab) can trigger specified builds (check ```DEBUG_LIST```, provided that ```BUILD_DEBUG == 1``` in ```trigger-build.yml```).
3. The triggered workflow executes a job responsible for fetching the corresponding build details for the given manifests. These details are extracted from the associated configuration yaml file, converted to JSON and passed to the next job.
4. Once the details have been extracted and collated, the ```build-qc-bsp-reusable.yml``` workflow located in *this* repository is *used* with each set of build parameters. The [matrix strategy](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) enables iteration over the sets of parameters, triggering a seperate build process for each configuration.
5. Upon receiving a set of details, the reusable workflow executes the build steps, broadly following the Qualcomm *Getting Started* build process. This continues until all triggered builds either complete, fail or are manually cancelled.
6. For non-development builds, the final build artifact is located in the corresponding build folder under ```/mnt/nvme1/qcom_ci/builds/[project_version]/release```. 

## Notes
- This process currently depends on a personal PAT for inter-repository access and should later be adapted to a service account or other user account independent token.
- As it stands, Qualcomm source files will need to be manually added to the *SHARED_SOURCES* directory. 
- Pushing a manifest that does not currently have a build directory will automatically create one; however, for now, any non-shared assets (i.e., patches, CDT, etc.) will have to be manually fetched and placed in it's *sources* folder.
  - In the event that build patches cannot be located in the specified build folder during the build process, [extract-sources.sh])https://github.com/imd-tec/qualcomm-ci/blob/master/scripts/extract-sources.sh) will default to patch archives located in: ```/mnt/nvme1/qcom_ci/builds/SHARED_SOURCES/fallback_patches/[project]/```.


