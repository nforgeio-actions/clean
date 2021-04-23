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
runner machine state in the future.  It's a good idea to execute this action as the first
step of a workflow to try to ensure that the runner is in a predictable state.

## Examples

**Clear runner state at the beginning of a workflow**
```
name: demo
on: [ workflow_dispatch ]
jobs:
  my-job:
    runs-on: self-hosted
    steps:
    - id: clean
      uses: nforgeio-actions/clean@master
    - id: setup-node
      uses: actions/setup-node@v2
      with:
        node-version: '14'    
    - id: environment
      uses: nforgeio-actions/environment@master
      with:
        master-password: ${{ secrets.DEVBOT_MASTER_PASSWORD }}
```
