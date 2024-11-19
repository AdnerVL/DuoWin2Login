# Duo Authentication Windows Logon Reinstallation Script

## Overview
This PowerShell script automates the uninstallation and reinstallation of the Duo Authentication for Windows Logon application on a remote Windows host.

## Disclaimer
🤖 **AI-Assisted Development**
This script was created with significant assistance from AI technologies. As the developer is not a professional PowerShell or software development expert, the code reflects a collaborative approach between human intent and AI-generated solutions.

## Features
- Remotely uninstall existing Duo Authentication
- Download latest Duo Authentication installer
- Install Duo Authentication with configurable parameters
- Robust error handling and logging
- Automatic cleanup of temporary files

## Prerequisites
- PowerShell 5.0 or higher
- Administrative access to target Windows machine
- Network connectivity to the remote host
- Valid Duo Security credentials (IKEY and SKEY)

## Usage
```powershell
.\DuoLoginReinstall.ps1 -hostname [COMPUTER_NAME]
```

## Configuration
Modify the following variables in the script as needed:
- `$duoVersion`: Duo Authentication version
- `$ikey`: Your Duo integration key
- `$skey`: Your Duo secret key
- `$dhost`: Duo API hostname

## Logging
Installation logs are saved to `C:\Tools\Script\DuoInstall.log`

## Caution
- Ensure you have proper authorization before running on any system
- Test in a controlled environment first
- Requires administrative permissions

## License
[Specify your license here]

## Contributing
Contributions, improvements, and bug reports are welcome!
