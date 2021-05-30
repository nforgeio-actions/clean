#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE GitHub runner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell | Out-Null
. ./includes.ps1
Pop-Location | Out-Null

# Fetch the inputs

$workspace  = Get-ActionInputBool "workspace"  $true
$builds     = Get-ActionInputBool "builds"     $true
$hyperv     = Get-ActionInputBool "hyperv"     $true
$xenserver  = Get-ActionInputBool "xenserver"  $true
$containers = Get-ActionInputBool "containers" $true
$wsl        = Get-ActionInputBool "wsl"        $true
$nuget      = Get-ActionInputBool "nuget"      $true
$neonkube   = Get-ActionInputBool "neonkube"   $true
$tmp        = Get-ActionInputBool "tmp"        $true

try
{
    # Clear the runner workspace.

    if ($workspace)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                        CLEAN GITHUB WORKSPACE                           ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""
        Clear-Directory $env:GITHUB_WORKSPACE -IgnoreErrors
    }

    # Use the [neon-build] tool (pre-built in neonKUBE) to clear the 
    # bin/obj folders in the local code repos.

    if ($builds)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                             CLEAN BUILDS                                ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        neon-build clean $env:NF_ROOT -all
        neon-build clean $env:NC_ROOT -all
        neon-build clean $env:NL_ROOT -all
    }

    # Stop and remove any local Hyper-V VMs.  Note that we don't need to 
    # remove the VHDX files here because they're located in the runner's 
    # workspace directory and will be removed when we clear that directory 
    # below.

    if ($hyperv)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                           CLEAN HYPER VMs                               ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        Get-VM | Stop-VM -TurnOff -Force
        Get-VM | Remove-VM -Force
    }

    # Stop and remove any VMs on the related XenServer/XCP-ng host and their
    # disks, filtering the VMs by cluster prefix.

    if ($xenserver)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                         CLEAN XENSERVER VMs                             ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        
    }

    # Delete all WSL distributions except for those belonging to Docker

    if ($wsl)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                          CLEAN WSL DISTROS                              ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        $distros = $(wsl --list --all --quiet)
        $distros = $distros.Split("`n")

        ForEach ($distro in $distros)
        {
            $distro = $distro.Trim()

            if ($distro.StartsWith("docker"))
            {
                Continue
            }

            wsl --unregister $distro
        }
    }

    # Purge all Docker assets including containers and images

    if ($containers)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                          CLEAN CONTAINERS                               ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        # Kill all running containers

        $containers = $(docker ps -q)

        if (![System.String]::IsNullOrEmpty($containers))
        {
            docker kill $containers
        }

        # Now purge all stopped containers, networks, and images

        docker system prune --all --force
    }

    # Clear the user's [.neonkube] directory

    if ($neonkube)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                          CLEAN [.neonkube]                              ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        Clear-Directory "$env:USERPROFILE\.neonkube" -IgnoreErrors
    }

    # Clear the nuget package caches

    if ($nuget)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                          CLEAN NUGET CACHE                              ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        nuget locals all -clear
    }

    # Clear the TMP directory

    if ($tmp)
    {
        Write-Info  ""
        Write-Info  "*******************************************************************************"
        Write-Info  "***                           CLEAN TMP FOLDER                              ***"
        Write-Info  "*******************************************************************************"
        Write-Info  ""

        Clear-Directory $env:TMP -IgnoreErrors
    }
}
catch
{
    Write-ActionException $_
    exit 1
}