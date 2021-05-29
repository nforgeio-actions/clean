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
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                        CLEAN GITHUB WORKSPACE                           ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""
        Clear-Directory $env:GITHUB_WORKSPACE -IgnoreErrors
    }

    # Use the [neon-build] tool (pre-built in neonKUBE) to clear the 
    # bin/obj folders in the local code repos.

    if ($builds)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                             CLEAN BUILDS                                ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

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
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                           CLEAN HYPER VMs                               ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        Get-VM | Stop-VM -TurnOff -Force
        Get-VM | Remove-VM -Force
    }

    # Stop and remove any VMs on the related XenServer/XCP-ng host and their
    # disks, filtering the VMs by cluster prefix.

    if ($xenserver)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                         CLEAN XENSERVER VMs                             ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        # $todo(jefflill): Implement this
    }

    # Purge all Docker assets including containers and images

    if ($containers)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                          CLEAN CONTAINERS                               ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        # Kill all running containers

        $containers = $(docker ps -q)

        if (![System.String]::IsNullOrEmpty($containers))
        {
            docker kill $containers
        }

        # Now purge all stopped containers, networks, and images

        docker system prune --all --force
    }

    # Delete all WSL distributions except for those belonging to Docker

    if ($wsl)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                          CLEAN WSL DISTROS                              ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        which wsl
        wsl --help

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

    # Clear the user's [.neonkube] directory

    if ($nuget)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                          CLEAN [.neonkube]                              ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        Clear-Directory "$env:USERPROFILE\.neonkube" -IgnoreErrors
    }

    # Clear the nuget package caches

    if ($nuget)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                          CLEAN NUGET CACHE                              ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        nuget locals all -clear
    }

    # Clear the TMP directory

    if ($tmp)
    {
        Write-Host  ""
        Write-Host  "*******************************************************************************"
        Write-Host  "***                           CLEAN TMP FOLDER                              ***"
        Write-Host  "*******************************************************************************"
        Write-Host  ""

        Clear-Directory $env:TMP -IgnoreErrors
    }
}
catch
{
    Write-ActionException $_
    exit 1
}