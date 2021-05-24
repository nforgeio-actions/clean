# clean

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason 
why this repo is public is because GitHub requires it.

Clears the runner state including:

* clearing the GITHUB_WORKSPACE directory
* clearing the TMP directory
* stopping any removing any Hype-V VMs

NOTE: You must run the **setup-node** action before this to ensure that Node.js is configured on the runner.

## Examples

**Clear runner state at the beginning of a workflow**
```
name: demo
on: [ workflow_dispatch ]
jobs:
  my-job:
    runs-on: self-hosted
    steps:

    # Run this first to ensure that Node.js is configured on the runner
    # because the [clean] action depends on this.

    - id: setup-node
      uses: actions/setup-node@v2

    # Clean the runner state.

    - id: clean
      uses: nforgeio-actions/clean@master
      with:
        node-version: '14'    

    # Remaining workflow steps:

    - id: environment
      uses: nforgeio-actions/environment@master
      with:
        master-password: ${{ secrets.DEVBOT_MASTER_PASSWORD }}
```
