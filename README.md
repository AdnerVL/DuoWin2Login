# 🔐 Duo Authentication Reinstallation Script

## 🚀 Overview
This PowerShell script automates the uninstallation and reinstallation of the Duo Authentication for Windows Logon application on a remote Windows host.

## 🤖 Disclaimer
**AI-Assisted Development**
This script was created with significant assistance from AI technologies. As the creator is not a professional PowerShell or software developer, the code reflects a collaborative approach between human intent and AI-generated solution.

## ✨ Features
* 🔄 Remotely uninstall existing Duo Authentication
* 📥 Download latest Duo Authentication installer
* 🛠️ Install Duo Authentication with configurable parameters
* 🛡️ Robust error handling and logging
* 🧹 Automatic cleanup of temporary files

## 📋 Prerequisites
* 💻 PowerShell 5.0 or higher
* 🔑 Administrative access to target Windows machine
* 🌐 Network connectivity to the remote host
* 🔐 Valid Duo Security credentials (IKEY and SKEY)

## 🚦 Usage

### 🛠️ 1. Environment Configuration
* Create a `.env` file in the script directory with your credentials:

```plaintext
IKEY=your_integration_key
SKEY=your_secret_key
DHOST=your-duo-host.com
```

### 🚀 2. Run the Script

```powershell
.\DuoLoginReinstall.ps1 [COMPUTER_NAME]
```

## 🛠️ Configuration
The script now uses environment variables for sensitive information:

* 📦 $duoVersion: Duo Authentication version
* 🔑 $ikey: Loaded from .env file
* 🔐 $skey: Loaded from .env file
* 🌐 $dhost: Loaded from .env file

## 📜 Logging
Installation logs are saved to C:\Tools\DuoInstall.log

## ⚠️ Caution
* 🛡️ Ensure you have proper authorization before running on any system
* 🧪 Test in a controlled environment first
* 🔒 Requires administrative permissions

## 🔒 Security Best Practices
* 📝 Add .env to .gitignore
* 🚫 Never commit sensitive credentials to version control
* 🔄 Rotate credentials periodically

## 📄 License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.

## 🤝 Contributing
Contributions, improvements, and bug reports are welcome!
