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

$default          = Get-ActionInputBool "default"           $true
$workspace        = Get-ActionInputBool "workspace"         $false $default
$builds           = Get-ActionInputBool "builds"            $false $default
$hyperv           = Get-ActionInputBool "hyperv"            $false $default
$xenserver        = Get-ActionInputBool "xenserver"         $false $default
$containers       = Get-ActionInputBool "containers"        $false $default
$wsl              = Get-ActionInputBool "wsl"               $false $default
$nuget            = Get-ActionInputBool "nuget"             $false $default
$neonkube         = Get-ActionInputBool "neonkube"          $false $default
$tmp              = Get-ActionInputBool "tmp"               $false $default
$pwshHistory      = Get-ActionInputBool "pwsh-history"      $false $default
$neonkubeFiles    = Get-ActionInput     "neonkube-files"    $false
$neonlibraryFiles = Get-ActionInput     "neonlibrary-files" $false
$neoncloudFiles   = Get-ActionInput     "neoncloud-files"   $false

try
{
    # Clear the runner workspace.

    if ($workspace)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                        CLEAN GITHUB WORKSPACE                           ***"
        Write-Info "*******************************************************************************"
        Write-Info ""
        Clear-Directory $env:GITHUB_WORKSPACE -IgnoreErrors
    }

    # Use the [neon-build] tool (pre-built in neonKUBE) to clear the 
    # bin/obj folders in the local code repos.

    if ($builds)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                             CLEAN BUILDS                                ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

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
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                          CLEAN HYPER-V VMs                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        Get-VM | Stop-VM -TurnOff -Force
        Get-VM | Remove-VM -Force
    }

    # Stop and remove any VMs on the related XenServer/XCP-ng host and their
    # disks, filtering the VMs by cluster prefix.

    if ($xenserver)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                         CLEAN XENSERVER VMs                             ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        $xenHostIP           = Get-ProfileValue "xen.host.ip"
        $xenOwner            = Get-ProfileValue "owner"
        $xenCredentialsName  = Get-ProfileValue "xen.credentials.name"
        $xenCredentialsVault = Get-ProfileValue "xen.credentials.vault"
        $xenUsername         = Get-SecretValue  "$xenCredentialsName[username]" $xenCredentialsVault
        $xenPassword         = Get-SecretValue  "$xenCredentialsName[password]" $xenCredentialsVault
        $xenserverIsRunning  = Check-XenServer  $xenHostIP $xenUsername $xenPassword

        if ($xenserverIsRunning)
        {
            Remove-XenServerVMs $xenHostIP $xenUsername $xenPassword "$xenOwner-*"
        }
    }

    # Delete all WSL distributions except for those belonging to Docker

    if ($wsl)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                          CLEAN WSL DISTROS                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        $distros = $(wsl --list --all --quiet)
        $distros = $distros.Split("`n")

        ForEach ($distro in $distros)
        {
            $distro = $distro.Trim()

            # Note that for some reason we're seeing a [0] byte for empty distros.

            if ([System.String]::IsNullOrEmpty($distro) -or ([int]$distro[0] -eq 0))
            {
                continue;
            }

            if ($distro.StartsWith("docker"))
            {
                # Don't mess with the Docker distros.

                Continue
            }

            "RUN: wsl --terminate $distro"
            wsl --terminate $distro

            "RUN: wsl --unregister $distro"
            wsl --unregister $distro
        }
    }

    # Purge all Docker assets including containers and images.  We're also  going to
    # ensure that Docker is not running in SWARM mode.  Some unit tests enable that.

    if ($containers)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                            CLEAN DOCKER                                 ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        # Remove all containers

        $containers = $(docker ps -a -q)

        if (![System.String]::IsNullOrEmpty($containers))
        {
            docker rm $containers --force
        }

        # Now purge all stopped containers, networks, and images

        docker system prune --all --force

        # Disable swarm mode

        $result = Invoke-CaptureStreams "docker swarm leave --force" -noCheck

        # Remove all Docker volumes

        $volumeNames = $(docker volume ls --format "{{ .Name }}")

        if (![System.String]::IsNullOrWhiteSpace($volumeNames))
        {
            $volumeNames = $volumeNames.Split("`n")

            ForEach ($volume in $volumeNames)
            {
                $volume = $volume.Trim()
                docker volume rm "$volume"
            }
        }
    }

    # Clear the user's [.neonkube] directory

    if ($neonkube)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                          CLEAN [.neonkube]                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        Clear-Directory "$env:USERPROFILE\.neonkube" -IgnoreErrors
    }

    # Clear the nuget package caches

    if ($nuget)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                          CLEAN NUGET CACHE                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        nuget locals all -clear
    }

    # Clear the TMP directory

    if ($tmp)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                           CLEAN TMP FOLDER                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        Clear-Directory $env:TMP -IgnoreErrors
    }

    # Clear the Powershell command history as described here:
    #
    #       https://www.shellhacks.com/clear-history-powershell/

    if ($pwshHistory)
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                       CLEAN POWERSHELL HISTORY                          ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        $historyPath = (Get-PSReadlineOption).HistorySavePath

        if ([System.IO.File]::Exists($historyPath))
        {
            [System.IO.File]::Delete($historyPath)
        }
    }

    # Remove repo files when requested

    if (![System.String]::IsNullOrWhiteSpace($neonkubeFiles) -and ![System.String]::IsNullOrWhiteSpace($neonlibraryFiles) -and ![System.String]::IsNullOrWhiteSpace($neoncloudFiles))
    {
        Write-Info ""
        Write-Info "*******************************************************************************"
        Write-Info "***                           CLEAN REPO FILES                              ***"
        Write-Info "*******************************************************************************"
        Write-Info ""

        function RemoveFiles
        {
            [CmdletBinding()]
            param (
                [Parameter(Position=0, Mandatory=$true)]
                [string]$repoRoot,
                [Parameter(Position=1, Mandatory=$true)]
                [string]$patterns
            )

"RemoveFiles 0: root:     $repoRoot"
"RemoveFiles 1: patterns: $patterns"

            if ([System.String]::IsNullOrEmpty($repo) -or [System.String]::IsNullOrWhiteSpace($patterns))
            {
"RemoveFiles 2:"
                return;
            }
"RemoveFiles 3:"

            $patterns = $patterns.Split(" ")
"RemoveFiles 4: $patterns"

            foreach ($pattern in $patterns)
            {
"RemoveFiles 5: pattern: $pattern"
                if ([System.String]::IsNullOrEmpty($pattern))
                {
"RemoveFiles 6:"
                    continue;
                }
"RemoveFiles 7:"

Write-Output [System.IO.Directory]::GetFiles($repoRoot, $pattern, "AllDirectories")
"RemoveFiles 8:"

                foreach ($file in [System.IO.Directory]::GetFiles($repoRoot, $pattern, "AllDirectories"))
                {
"RemoveFiles 9:"
                    Write-Info "removing: $file"
                    [System.IO.File]::Delete($file)
                }
            }
        }

"neonkubeFiles:    $neonkubeFiles"
"neonlibraryFiles: $neonlibraryFiles"
"neoncloudFiles:   $neoncloudFiles"
        RemoveFiles $env:NF_ROOT $neonkubeFiles
        RemoveFiles $env:NL_ROOT $neonlibraryFiles
        RemoveFiles $env:NC_ROOT $neoncloudFiles
    }
}
catch
{
    Write-ActionException $_
    exit 1
}
