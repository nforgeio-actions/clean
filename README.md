# clean

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason 
why this repo is public is because GitHub requires it.

Cleans transient workflow state like the working directory.

It appears that the GitHub runner does not try very hard to clear temporary state on self-hosted 
runners after the workflow completes or fails (which is probably a good thing by enabling workflow
post mortems).

I was surprised though that the runner doesn't clear existing state before starting a new workflow.
Perhaps this is because GiHub hosted runners are new born for every workflow execution.

This action currently clears the GITHUB_WORKSPACE directory and may potentially clear other
runner machine state in the future.  It's a good idea to execute this action as the second
step of a workflow (after configuring Node.js) to try to ensure that the runner is in a 
predictable state.  You may also wish to call this at the end of your workflow to remove
any potentially sensitive files run the runner.

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
