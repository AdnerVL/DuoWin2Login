# Duo Authentication Windows Logon Reinstallation Script

## Overview
This PowerShell script automates the uninstallation and reinstallation of the Duo Authentication for Windows Logon application on a remote Windows host.

## Disclaimer
🤖 **AI-Assisted Development**
This script was created with significant assistance from AI technologies. As the creator is not a professional PowerShell or software developer, the code reflects a collaborative approach between human intent and AI-generated solution.

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
Installation logs are saved to `C:\Tools\DuoInstall.log`

## Caution
- Ensure you have proper authorization before running on any system
- Test in a controlled environment first
- Requires administrative permissions

## License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.

## Contributing
Contributions, improvements, and bug reports are welcome!
