# Local Development Environment

This project is designed to start local-first before adding cloud resources.
The first environment goal is to verify the workstation and shell context, not to create a Kubernetes cluster yet.

## Supported Shells

The repository can be inspected from:

- WSL2 Ubuntu or another Linux distribution
- Windows PowerShell or PowerShell 7
- Git Bash for Windows

For day-to-day platform engineering work, prefer one primary execution environment per task. Mixing Windows and WSL binaries can work, but it is a common source of path, Docker socket, file permission, and line-ending issues.

## Required CLI Tools

The prereq checks look for these tools:

- `git`
- `docker`
- `kubectl`
- `helm`
- `kind`
- `go`
- `terraform`
- `ansible`
- `gh`

The scripts print each detected binary path and version. They also check Docker daemon availability and the active Docker context.

## Environment Detection

The checks identify whether they appear to be running from:

- WSL2
- Git Bash / MSYS / MinGW
- PowerShell on Windows
- Linux/macOS shell

They also warn about mixed Windows/WSL tooling. Examples include calling Windows `.exe` tools from WSL, or using WSL-backed wrappers from Git Bash. Mixed setups are not always wrong, but they should be intentional and visible.

## Running the Checks

From WSL2 or Git Bash:

```bash
bash scripts/check-prereqs.sh
```

From PowerShell:

```powershell
.\scripts\check-prereqs.ps1
```

If PowerShell blocks local scripts, run the check for the current session only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-prereqs.ps1
```

## Expected Behavior

The scripts do not:

- install packages
- create Kubernetes clusters
- require cloud credentials
- read or print secrets
- authenticate to GitHub, cloud providers, or registries

The scripts do:

- print detected environment information
- print tool versions and binary paths
- report missing tools as warnings
- report Docker daemon availability
- report the active Docker context when possible
- exit with a non-zero status if important checks fail

## Ansible on Windows

Ansible is best used from Linux or WSL2 as the control node. Native Windows Ansible installations can fail because Ansible's control-node support targets Unix-like environments. If you are on Windows, prefer installing Ansible inside WSL2 and expose a wrapper only if you intentionally want Git Bash or PowerShell to call the WSL install.

## Docker Notes

Docker CLI availability does not guarantee the daemon is running. The checks separately test:

- whether the `docker` command exists
- whether `docker info` can reach the daemon
- which Docker context is active

For local Kubernetes with `kind`, Docker Desktop or another compatible local Docker daemon must be running before cluster creation.

## Troubleshooting

If a tool is found but behaves incorrectly:

1. Check the printed binary path.
2. Confirm whether it is a Windows, WSL, or Git Bash/MSYS path.
3. Open a fresh terminal after changing `PATH`.
4. Prefer one toolchain source per environment, such as WSL packages inside WSL and Windows binaries inside PowerShell/Git Bash.
