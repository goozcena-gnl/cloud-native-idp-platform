$ErrorActionPreference = "Continue"

$Tools = @("git", "docker", "kubectl", "helm", "kind", "go", "terraform", "ansible", "gh")
$Warnings = 0

function Write-Section {
    param([string]$Name)
    Write-Host ""
    Write-Host "== $Name =="
}

function Write-WarningMessage {
    param([string]$Message)
    $script:Warnings++
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Invoke-ToolCommand {
    param([string[]]$Command)

    try {
        $output = & $Command[0] @($Command | Select-Object -Skip 1) 2>&1
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = @($output | ForEach-Object { $_.ToString() })
        }
    }
    catch {
        [pscustomobject]@{
            ExitCode = 1
            Output = @($_.Exception.Message)
        }
    }
}

function Get-VersionCommand {
    param([string]$Tool)

    switch ($Tool) {
        "git" { @("git", "--version") }
        "docker" { @("docker", "--version") }
        "kubectl" { @("kubectl", "version", "--client") }
        "helm" { @("helm", "version", "--short") }
        "kind" { @("kind", "version") }
        "go" { @("go", "version") }
        "terraform" { @("terraform", "version") }
        "ansible" { @("ansible", "--version") }
        "gh" { @("gh", "--version") }
    }
}

function Get-EnvironmentKind {
    if ($env:WSL_INTEROP -or $env:WSL_DISTRO_NAME) {
        return "WSL/Linux on Windows"
    }

    if ($env:MSYSTEM -or $env:MINGW_PREFIX) {
        return "Git Bash / MSYS on Windows"
    }

    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return "PowerShell on Windows"
    }

    if ($IsLinux) {
        return "PowerShell on Linux"
    }

    if ($IsMacOS) {
        return "PowerShell on macOS"
    }

    "Unknown PowerShell environment"
}

function Test-MixedTooling {
    param(
        [string]$Tool,
        [string]$Path
    )

    if ($Path -match "Microsoft\\WindowsApps" -and $Tool -ne "winget") {
        Write-WarningMessage "$Tool resolves through WindowsApps; verify this is the intended binary"
    }

    if ($Tool -eq "ansible" -and $Path -match "PythonSoftwareFoundation") {
        Write-WarningMessage "native Windows Ansible detected; prefer WSL-backed Ansible for control-node usage"
    }

    if ($Path -match "\\wsl\\|wsl\.exe") {
        Write-WarningMessage "$Tool appears to use WSL from PowerShell; mixed Windows/WSL tooling should be intentional"
    }
}

function Check-Tool {
    param([string]$Tool)

    Write-Host ""
    Write-Host "[$Tool]"

    $command = Get-Command $Tool -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        Write-WarningMessage "$Tool is missing from PATH"
        return
    }

    $path = $command.Source
    if (-not $path) {
        $path = $command.Path
    }

    Write-Host "Path: $path"
    Test-MixedTooling -Tool $Tool -Path $path

    $versionCommand = Get-VersionCommand $Tool
    $result = Invoke-ToolCommand -Command $versionCommand

    if ($result.ExitCode -ne 0) {
        Write-WarningMessage "$Tool version command failed: $($versionCommand -join ' ')"
        if ($result.Output.Count -gt 0) {
            Write-Host $result.Output[0]
        }
        return
    }

    $linesToShow = if ($Tool -in @("ansible", "gh", "terraform")) { 4 } else { 1 }
    $result.Output | Select-Object -First $linesToShow | ForEach-Object { Write-Host $_ }
}

function Check-DockerRuntime {
    Write-Section "Docker Runtime"

    $docker = Get-Command docker -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $docker) {
        Write-WarningMessage "docker is missing; daemon checks skipped"
        return
    }

    Write-Host "Docker binary: $($docker.Source)"

    $context = Invoke-ToolCommand -Command @("docker", "context", "show")
    if ($context.ExitCode -eq 0 -and $context.Output.Count -gt 0) {
        Write-Host "Docker context: $($context.Output[0])"
    }
    else {
        Write-WarningMessage "could not read Docker context"
        if ($context.Output.Count -gt 0) {
            Write-Host $context.Output[0]
        }
    }

    $info = Invoke-ToolCommand -Command @("docker", "info", "--format", "{{.ServerVersion}}")
    if ($info.ExitCode -eq 0 -and $info.Output.Count -gt 0) {
        Write-Host "Docker daemon: available"
        Write-Host "Docker server version: $($info.Output[0])"
    }
    else {
        Write-WarningMessage "Docker daemon is not reachable; start Docker Desktop or your configured daemon"
        if ($info.Output.Count -gt 0) {
            Write-Host $info.Output[0]
        }
    }
}

Write-Section "Environment"
Write-Host "Detected environment: $(Get-EnvironmentKind)"
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "OS: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
Write-Host "PWD: $(Get-Location)"

Write-Section "Tools"
foreach ($tool in $Tools) {
    Check-Tool -Tool $tool
}

Check-DockerRuntime

Write-Section "Summary"
if ($Warnings -eq 0) {
    Write-Host "All prerequisite checks passed."
    exit 0
}

Write-Host "Completed with $Warnings warning(s). Review the messages above."
exit 1
