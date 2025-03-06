# 🔐 Duo Authentication Reinstallation Script

## 🚀 Overview
This project automates the uninstallation and reinstallation of Duo Authentication for Windows Logon on a Windows host, either locally or remotely. It includes a PowerShell script (`DuoWin2Login.ps1`) and a batch file wrapper (`Install.bat`) for easy execution.

## 🤖 Disclaimer
**AI-Assisted Development**  
This script was developed with significant assistance from AI technologies. As the creator is not a professional PowerShell or software developer, the code reflects a collaborative effort between human intent and AI-generated solutions.

## ✨ Features
- 🔄 Remotely or locally uninstall existing Duo Authentication
- 📥 Download the latest or specified Duo Authentication installer
- 🛠️ Install Duo with configurable parameters (e.g., autopush, failopen)
- 📊 Visual progress tracking with loading animations and progress bars
- 🛡️ Robust error handling and detailed logging
- 🧹 Automatic cleanup of temporary files on both local and target systems
- 🎨 Color-coded console output for enhanced user experience
- 🔇 Optional suppression of success messages via `-QuietSuccess`

## 📋 Prerequisites
- 💻 PowerShell 5.0 or higher
- 🔑 Administrative access to the target Windows machine
- 🌐 Network connectivity to the target host and Duo’s servers
- 🔐 Valid Duo Security credentials (IKEY, SKEY, DHOST)
- 📜 `.bat` file requires elevation if not run as Administrator

## 🚦 Usage

### 🛠️ 1. Environment Configuration
Create a `.env` file in the script directory with your Duo credentials:

```plaintext
IKEY=your_integration_key
SKEY=your_secret_key
DHOST=your-duo-host.com
```

### 🚀 2. Run the Script
#### Using the Batch File (Recommended):
```cmd
Install.bat [COMPUTER_NAME]
```
- If no `COMPUTER_NAME` is provided, you’ll be prompted for one.
- Use `localhost` for local installation.
- The `.bat` file handles elevation and execution policy bypass.

#### Direct PowerShell Execution:
```powershell
.\DuoWin2Login.ps1 -hostname [COMPUTER_NAME]
```
- Ensure execution policy allows scripts (`Set-ExecutionPolicy Bypass`).

### Example Output
```
+===============================+
    DUO WINDOWS LOGON INSTALL    
+===============================+
Scanning access vectors...
Locating quantum module...
Hacking neural protocols...
Initializing quantum auth...
Select Duo version to install:
1) Latest version
2) Version 4.3.1 (default)
Enter 1 or 2 (press Enter for default):
[NEON_BOOT] Waiting for PsExec preparation to complete...  *  *  *  *  *
Waiting for PsExec preparation to complete...   23% [======........................]
```

## 🛠️ Configuration
- **Environment Variables (from `.env`):**
  - `$ikey`: Integration key
  - `$skey`: Secret key
  - `$dhost`: Duo API hostname
- **Script Variables:**
  - `$duoVersion`: Select latest (scraped from Duo’s site) or 4.3.1 (default)
  - `$autopush = "#1"`: Enables autopush (configurable)
  - `$failopen = "#0"`: Disables failopen (configurable)
  - `$smartcard = "#0"`: Disables smartcard (configurable)
  - `$rdponly = "#0"`: Disables RDP-only mode (configurable)

## 📜 Logging
- **Console:** Shows progress, errors, and optional success messages.
- **File:** Detailed logs saved to `%TEMP%\DuoInstallLog.txt` (e.g., `C:\Users\YourUser\AppData\Local\Temp\DuoInstallLog.txt`).
- **MSI Log:** Installation details saved to `C:\Tools\DuoInstall.log` on the target machine (deleted post-install).

## ⚠️ Caution
- 🛡️ Ensure proper authorization before running on any system.
- 🧪 Test in a controlled environment first.
- 🔒 Requires administrative permissions on both local and target machines.
- 🌐 Internet access needed for downloading PsExec and Duo files.

## 🔒 Security Best Practices
- 📝 Add `.env` to `.gitignore` to prevent credential exposure.
- 🚫 Never commit sensitive credentials to version control.
- 🔄 Rotate Duo credentials periodically.
- 🔐 Run with least privilege where possible, elevating only when necessary.

## 📄 License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

## 🤝 Contributing
Contributions, improvements, and bug reports are welcome! Please submit pull requests or issues via GitHub.

## 🐞 Known Issues
- Fixed `FileStream` error in local cleanup (Step 16) by replacing `cmd /c del` with `Remove-Item`.

## 📅 Last Updated
March 5, 2025
