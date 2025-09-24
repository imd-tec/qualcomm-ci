QUALCOMM CI

Automates fetching of sources and build process.

- All referenced files are stored under */mnt/nvme1/qcom_ci/* on the qcom desktop.
- For a given build version, set the appropriate environment variables (source ver, build ver, docker ver, manifests, etc.) in the *env* section of the respective workflow.
- There are optional flags for fresh extraction of source files and removal of source files upon build completion. Enable *KEEP_BUILD* for use of completed build image.
