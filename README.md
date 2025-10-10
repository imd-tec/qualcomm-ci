QUALCOMM CI

Automates fetching of sources and build process for Qualcomm SBC builds. Adapted from the *IMDT SBC8550 BSP Getting Started Guide*.

- All referenced files are stored under */mnt/nvme1/qcom_ci/* on the qcom desktop.
- For a given hard-coded build version, set the appropriate environment variables (source ver, build ver, docker ver, manifests, etc.) in the *env* section of the respective workflow.
- For the reusable workflow, builds are triggered from a corresponding workflow on a manifest repo.
-   Build details are then extracted from the manifest and source repo itself from the calling repo (WIP).
- There are optional flags for fresh extraction of source files and removal of source files upon build completion. Enable *KEEP_BUILD* to create build artifact.
