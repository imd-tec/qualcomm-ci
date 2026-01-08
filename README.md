# QUALCOMM BUILD AUTOMATION

Automates fetching of sources and build processes for Qualcomm-based projects as adapted from the **Qualcomm Getting Started** guides. 

## Requirements
**GitHub**
- A private Qualcomm manifest repository that:
  - Contains the ```trigger-build.yml``` workflow under ```.github/workflows```.
    - See [```for-manifest-repo/trigger-build-ci```](https://github.com/imd-tec/qualcomm-ci/blob/master/for_manifest_repo/trigger-build-ci.yml).
  - Has a PAT secret for inter-repo read access.
  
  - Has a single yml configuration file located at the same depth as the manifest xml files, outlining the build details for each manifest version.
    - See [```for-manifest-repo/config_example.yml```](https://github.com/imd-tec/qualcomm-ci/blob/master/for_manifest_repo/config_example.yml) for a template.
- The ***imdt-qcom-desktop*** self-hosted runner must be shared to the manifest repository.

**Runner setup**
- The self-hosted `actions.runner` service must be:
  - Run as a user with a configured `.netrc`.

  - Configured with the following environment variables:
      | Environment variable | Description |
      | -------- | ------- |
      | `CI_DIR` | Root CI directory |
      | `BSP_SOURCES_DIR` | Directory containing versioned QCS release folders (i.e, `qcs8550-le-1-0_amss_standard_oem_apqgps-r00087.1/`) |
      | `CI_DEV_DIR` | Directory containing development build logs |
      | `DL_DIR` | Yocto download cache location |
      | `SSTATE_DIR` | Yocto shared state cache location |

- The runner must contain the required Qualcomm source release archive at ```$BSP_SOURCES_DIR/<qcs_sources>/```.
  - The name of the `<qcs_sources>` directory must exactly match the `qcs_sources` value defined in the build configuration yaml. 

  - An optional ```patches.tar.gz``` archive may also be included in this directory. 
    - **Note**: The workflow currently only supports `sync_snap_v2_remove_chipcode_copy.patch`.

## How it works
### Release builds
1. A push affecting (or creating) a manifest file triggers ```trigger-build.yml``` on the manifest repository.
    - Alternatively, manual dispatch (under the **Actions** tab) can force specified builds (development or by input space-separated list).
2. The triggered workflow executes the `get_changed_manifests` job, responsible for fetching the corresponding build details for the changed manifests, where applicable. These details are extracted from the associated configuration yaml file, converted to JSON and passed to the `build` job.

3. Once the details have been extracted and collated, the ```imdt-build-qcom-bsp.yml``` workflow located in *this* repository is *used* with each set of build parameters. The [matrix strategy](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) enables iteration over the sets of parameters, triggering a separate build process for each configuration.
4. Upon receiving a set of details, `imdt-build-qcom-bsp.yml` executes the build steps, broadly following the Qualcomm *Getting Started* build process. This continues until all triggered builds either complete, fail or are manually cancelled.
5. The final build artifacts are located in corresponding build folder under ```$CI_DIR/builds/<project_version>/release```. 

### Development builds
1. A cron-job triggers ```trigger-build.yml``` on the manifest repository.

2. All project development build attempts are logged in a corresponding `.last` state file stored in `$CI_DEV_DIR/state`. To handle non-static meta-layer branch revisions specified in the manifest, this state file records both the build status and the fetched meta-layer hashes of the most recent build attempt.
3. The [`poll-development-repo.sh`](https://github.com/imd-tec/qualcomm-ci/blob/master/scripts/poll-development-repo.sh) script locates and accesses the `development.xml` manifest and determines the branch revision meta-layers to poll for changes.
4. If not previously cached in `$CI_DEV_DIR/cache`, all detected meta-layer repositories are cloned, and their current branch hashes are fetched and diff-checked against the meta-layer hashes stored in the build state file.
5. The rubric for a build trigger is as follows:
    | Case | Build? |
    | -------- | ------- |
    | No state file found  | YES   |
    | State file not labelled `SUCCESS` | YES     |
    | State file labelled `SUCCESS` and branch revisions are up to date | NO |
    | State file labelled `SUCCESS`, branch revisions are not up to date and non-relevant files changed  | NO  |
    | State file labelled `SUCCESS`, branch revisions are not up to date and relevant files changed  | YES    |
    
    See [`poll-development-repo.sh`](https://github.com/imd-tec/qualcomm-ci/blob/master/scripts/poll-development-repo.sh) for more details.
6. Upon build attempt, the build job status is logged to the project state file.

## Notes
- Upon build conclusion, all build directories and Docker resources are normally automatically deleted. 
  - However, under the **Actions** tab, manually dispatched builds have the option to preserve these resources (located at `$CI_DIR/builds/PRESERVED_BUILDS/`) for further debugging or artifact creation.
  - **NOTE**: Developers are responsible for manual clean-up of preserved resources.  
- By design, only development builds utilize Yocto caching. Release builds must fetch fresh meta-layer sources to ensure reproducibility.
- This process currently depends on a personal PAT for inter-repository access and should later be adapted to a service account or other user account independent token.
- Pushing a development change manifest will trigger a build and log the success status as expected. However, currently, triggering a development build this way will omit the hash logging step and thus the next cron-job will trigger another build regardless of success status. 

