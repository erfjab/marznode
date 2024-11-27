# MarzNode Script

The `marznode` script helps manage the installation, updates and maintenance of MarzNode and its Xray core dependencies. This tool includes commands for installing and controlling the MarzNode service (with `custom xray version`), as well as a built-in system for checking and installing required dependencies.

why is archive? because rate of adding Marzneshin cores was faster than my update speed.

## Features

- **Install/Uninstall MarzNode**: Easily install or remove MarzNode.
- **Start/Stop/Restart**: Manage the MarzNode service (start, stop, or restart).
- **Logs**: View recent MarzNode logs.
- **Docker Integration**: MarzNode runs as a Docker service.
- **Custom Port Configuration**: Specify the service port during installation.

## Installation

To install the script itself and be able to run it from anywhere, follow these steps:

1. Download and Install the script:
    ```bash
    sudo bash -c "$(curl -sL https://raw.githubusercontent.com/erfjab/marznode/main/install.sh)" @ install-script
    ```

2. You can now run the script using the `marznode` command.

## Usage

After installation, the script provides multiple commands to manage MarzNode. Here are the basic commands you can use:

### Install MarzNode

To install MarzNode along with the required dependencies, run:
```bash
marznode install
```
You will be asked to provide a service port and the MarzNode certificate from the Marzneshin panel.

### Start/Stop/Restart MarzNode

- Start the MarzNode service:
    ```bash
    marznode start
    ```
- Stop the MarzNode service:
    ```bash
    marznode stop
    ```
- Restart the MarzNode service:
    ```bash
    marznode restart
    ```

### Show MarzNode Status

To check if MarzNode is running and view the uptime:
```bash
marznode status
```

### View Logs

To view recent logs of MarzNode:
```bash
marznode logs
```

### Uninstall MarzNode

To uninstall MarzNode and remove all related files:
```bash
marznode uninstall
```

### Script Version

To check the current version of the script:
```bash
marznode version
```

## Updating the Script

To update the script itself:
```bash
marznode update-script
```

## Uninstall the Script

To uninstall the script and remove it from `/usr/local/bin`:
```bash
marznode uninstall-script
```

## Full Command List

```bash
marznode install          # Install MarzNode
marznode uninstall        # Uninstall MarzNode
marznode start            # Start MarzNode service
marznode stop             # Stop MarzNode service
marznode restart          # Restart MarzNode service
marznode status           # Show MarzNode status
marznode logs             # Show MarzNode logs
marznode version          # Show script version
marznode install-script   # Install this script to /usr/local/bin
marznode uninstall-script # Uninstall this script from /usr/local/bin
marznode update-script    # Update this script to the latest version
marznode help             # Show help message
```
