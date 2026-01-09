# Duo Authentication Installer for Windows

This tool helps you install or reinstall Duo Authentication for Windows Logon on your computer or a remote Windows machine. It handles downloading the software, uninstalling old versions, and setting it up with your Duo credentials.

## What You Need
- Windows computer with PowerShell 5.0 or newer
- Admin rights on the target machine
- Internet connection for downloading files
- Your Duo integration key, secret key, and API hostname

## Setup
1. Download or copy the script files to a folder on your computer.
2. Create a file named `.env` in the same folder with your Duo details:
   ```
   IKEY=your_integration_key_here
   SKEY=your_secret_key_here
   DHOST=your-duo-hostname.com
   ```
   Replace the placeholders with your actual Duo credentials.

## How to Run

### Recommended Quick Method (Admin PowerShell)
Sometimes the only reliable way is to unblock the script and run it directly from an elevated PowerShell console.

1. Unblock the script: right-click `DuoWin2Login.ps1` > Properties > check "Unblock" > OK. (Alternatively, in PowerShell: `Unblock-File .\DuoWin2Login.ps1`)
2. Run PowerShell as Administrator.
3. Navigate to the folder and run: `.\DuoWin2Login.ps1 -hostname <computer>`

Replace `<computer>` with `localhost` for local install, or the remote computer's name/IP.

### Alternative: Using Batch File
Use the `Install.bat` file for easy setup. It will handle everything automatically.

- Double-click `Install.bat` and follow the prompts for the computer name.
- Or run it from the command line: `Install.bat`

#### Examples
- **Local Install**: `Install.bat localhost` (installs on your own computer)
- **Remote by Hostname**: `Install.bat MyComputer` (replace with the remote computer's name)
- **Remote by IP Address**: `Install.bat 192.168.1.100` (use the IP of the remote computer)

The script will ask if you want the latest version or an older one (4.3.1). If you don't choose in 3 seconds, it picks the latest automatically.

## What Happens During Install
- Checks network and permissions
- Downloads needed tools
- Removes any old Duo software
- Downloads and installs the new version
- Cleans up temporary files
- Logs everything to `%TEMP%\DuoInstallLog.txt`

## Important Notes
- Test on a non-production machine first.
- You need admin access on both your computer and the target.
- Keep your `.env` file safe and don't share it.
- The script requires internet access to download Duo files.

## Troubleshooting
- If you get "Access is denied", unblock the files: right-click each file > Properties > check "Unblock" > OK. If that doesn't work, use `Unblock-File .\filename` in PowerShell. If permissions issues persist, take ownership: `takeown /f "path\to\file"` and grant access: `icacls "path\to\file" /grant "yourusername":F`.
- If it fails, check the log file for details.
- Make sure PowerShell scripts are allowed (run as admin if needed).
- For remote installs, ensure the target computer is reachable and you have permissions.

## License
This is free software under the GNU General Public License v3. See the full license for details.

Last updated: January 9, 2026