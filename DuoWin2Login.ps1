# PURPOSE:
# Uninstall and reinstall the Duo Login application to fix issue(s) such as user not being prompted on login.

param(
    [Parameter(Mandatory=$false)]
    [string]$hostname
)

# If hostname is not provided, prompt the user
if ([string]::IsNullOrWhiteSpace($hostname)) {
    $hostname = Read-Host "Please enter the hostname"
}

# Validate that hostname is not empty after prompting
if ([string]::IsNullOrWhiteSpace($hostname)) {
    Write-Error "Hostname cannot be empty. Script cannot continue."
    exit
}

$duoVersion = "4.3.1"
$ikey = "SecretKey"
$skey = "secretKey" 

# Ensure C:\Tools\Script folder exists
$folderPath = "C:\Tools\Script"
if (!(Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath | Out-Null
}

# Download PsTools
$psToolsZipPath = Join-Path $folderPath "PSTools.zip"

try {
    Write-Host "Downloading PSTools.zip..."
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile $psToolsZipPath
    
    # Extract only PsExec.exe
    Write-Host "Extracting PsExec.exe..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($psToolsZipPath)
    
    try {
        $psExecEntry = $zip.Entries | Where-Object { $_.Name -eq "PsExec.exe" }
        
        if ($psExecEntry) {
            $outputPath = Join-Path $folderPath "PsExec.exe"
            $entryStream = $psExecEntry.Open()
            $fileStream = [System.IO.File]::Create($outputPath)
            
            try {
                $entryStream.CopyTo($fileStream)
                Write-Host "PsExec.exe extracted successfully."
            }
            finally {
                $fileStream.Close()
                $entryStream.Close()
            }
        }
        else {
            Write-Error "PsExec.exe not found in the zip file."
        }
    }
    finally {
        $zip.Dispose()
    }
}
catch {
    Write-Error "Failed to download or extract PSTools: $_"
    exit
}

#Check Connectivity and use PsExec to Enable PowerShell connection on remote host
try {
    # Test network connectivity
    if (Test-Connection -ComputerName $hostname -Count 2 -Quiet) {
        Write-Host "Computer $hostname is reachable"
        
        # Attempt PsExec with full diagnostic output
        $result = cmd /c "C:\Tools\Script\PsExec.exe" "\\$hostname" -s powershell.exe -ExecutionPolicy Bypass -Command "Restart-Service WinRM" 2>&1 | Out-Null
        
        Write-Host "WinRM service restart attempted on $hostname"
    } else {
        Write-Error "Cannot reach computer $hostname"
    }
} catch {
    Write-Error "Error occurred: $_"
}

# Function to list installed applications on the remote host
function Get-InstalledAppsRemote {
    #param (
    #    [string]$hostname
    #)

    try {
        # Execute command on the remote host to list installed applications
        $apps = Invoke-Command -ComputerName $hostname -ScriptBlock {
            # Use Get-CimInstance for better performance
            Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name, Version
        }

        # Display the list of applications in a table format
        if ($apps) {
            Write-Output "Installed applications on ${hostname}:"
            $apps | Format-Table -Property Name, Version -AutoSize
        } else {
            Write-Output "No applications found or unable to retrieve applications on $hostname."
        }
        return $apps
    }
    catch {
        Write-Output "Failed to connect to $hostname or retrieve applications."
        Write-Output $_.Exception.Message
        return $false
    }
}

# Check and create the folder on the remote computer
Invoke-Command -ComputerName $hostname -ScriptBlock {
    param([string]$remoteFolderPath)
    
    Write-Host "Attempting to verify/create folder: $remoteFolderPath"
    
    try {
        if (-not (Test-Path -Path $remoteFolderPath -ErrorAction Stop)) {
            New-Item -ItemType Directory -Path $remoteFolderPath -Force -ErrorAction Stop
            Write-Host "Folder created at $remoteFolderPath"
        } else {
            Write-Host "Folder already exists at $remoteFolderPath"
        }
    }
    catch {
        Write-Error "Error accessing/creating path: $remoteFolderPath"
        Write-Error $_.Exception.Message
    }
} -ArgumentList $folderPath

# Function to download Duo Authentication for Windows Logon using curl on the remote host
function Download-FileRemote {
    param (
        [string]$hostname,
        [string]$url,
        [string]$path
    )

    try {
        # Execute command on the remote host to download the file
        Write-Output "Downloading Duo application from official Duo website."
        Invoke-Command -ComputerName $hostname -ScriptBlock {
            param (
                [string]$url,
                [string]$path
            )
            $outputPath = Join-Path -Path $path -ChildPath "DUO.ZIP"
            $curlCommand = "curl -o `"$outputPath`" `"$url`""
            Invoke-Expression -Command $curlCommand
        } -ArgumentList $url, $path
    }
    catch {
        Write-Output "Failed to download file on $hostname."
        Write-Output $_.Exception.Message
    }
}

# Function to extract DuoWindowsLogon64.msi from DUO.ZIP and copy to C:\tools on the remote host
function Extract-DuoMsiRemote {
    param (
        [string]$hostname,
        [string]$zipPath,
        [string]$extractPath
    )

    try {
        # Execute command on the remote host to extract DuoWindowsLogon64.msi from DUO.ZIP
        Invoke-Command -ComputerName $hostname -ScriptBlock {
            param (
                [string]$zipPath,
                [string]$extractPath
            )
            
            # Check if the zip file exists
            if (!(Test-Path -Path $zipPath)) {
                Write-Output "DUO.ZIP not found on $using:hostname."
                return
            }

            # Create extraction directory if it doesn't exist
            if (!(Test-Path -Path $extractPath)) {
                New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
            }

            # Load ZIP assembly
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            $targetFile = "DuoWindowsLogon64.msi"
            $destination = Join-Path -Path $extractPath -ChildPath $targetFile

            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
                $entry = $zip.Entries | Where-Object { $_.Name -eq $targetFile }

                if ($entry) {
                    # Extract single file
                    $extractStream = [System.IO.File]::Create($destination)
                    $entryStream = $entry.Open()
                    $entryStream.CopyTo($extractStream)
                    $extractStream.Close()
                    $entryStream.Close()
                    Write-Output "DuoWindowsLogon64.msi extracted successfully."
                } else {
                    Write-Output "DuoWindowsLogon64.msi not found in DUO.ZIP on $using:hostname."
                }
            }
            finally {
                if ($zip) {
                    $zip.Dispose()
                }
            }
        } -ArgumentList $zipPath, $extractPath
    }
    catch {
        Write-Output "Failed to extract DuoWindowsLogon64.msi on $hostname."
        Write-Output $_.Exception.Message
    }
}

# Function to uninstall Duo from the remote host
function Uninstall-DuoRemote {
    param (
        [string]$hostname
    )

    try {
        # Execute command on the remote host to uninstall Duo
        Invoke-Command -ComputerName $hostname -ScriptBlock {
            $result = wmic product where 'name="Duo Authentication for Windows Logon x64"' call uninstall /nointeractive
        } -ErrorAction SilentlyContinue
        Write-Output $result
        Write-Output "Existing Duo install removed."
    }
    catch {
        Write-Output "Failed to uninstall Duo on $hostname."
        Write-Output $_.Exception.Message
    }
}

# Call the functions
Uninstall-DuoRemote -hostname $hostname
Download-FileRemote -hostname $hostname -url "https://dl.duosecurity.com/DuoWinLogon_MSIs_Policies_and_Documentation-$($duoVersion).zip" -path "C:\Tools\Script"
Extract-DuoMsiRemote -hostname $hostname -zipPath "C:\Tools\Script\DUO.ZIP" -extractPath "C:\Tools\Script"

# Define necessary parameters for installation
$msiPath = "C:\tools\Script\DuoWindowsLogon64.msi"
$dhost = "api.duosecurity.com"
$autopush = "#1"
$failopen = "#0"
$smartcard = "#0"
$rdponly = "#0"
$logPath = "C:\Tools\DuoInstall.log"
$folderPath = "C:\Tools\Script"

# Prepare the msiexec command with detailed logging
$msiexecCommand = "msiexec /i `"$msiPath`" IKEY=`"$ikey`" SKEY=`"$skey`" HOST=`"$dhost`" AUTOPUSH=`"$autopush`" FAILOPEN=`"$failopen`" SMARTCARD=`"$smartcard`" RDPONLY=`"$rdponly`" /qn /l*v `"$logPath`""

# Execute the msiexec command remotely using Invoke-Command
Invoke-Command -ComputerName $hostname -ScriptBlock {
    param (
        $msiexecCommand,
        $logPath
    )
    
    try {
        # Attempt to run the msiexec command
        Invoke-Expression -Command $msiexecCommand
        Write-Output "Installation command executed."

        # things don't always work, so check if they worked this try. Retry a couple times if it did not work...
        $iters = 0
        $maxIters = 3
        $success = $false # assume false until we find it actually there
        while(!$success -and ($iters -lt $maxIters)){
            $iters++ # increment by 1
            # Check if the install succeeded.
            Write-Output "Reading installed applications..."
            # wait a few seconds to make sure that the list of installed apps will include a very recently succeeded install. 
            # we found when testing that sometimes a successful install would not be recognized when the Get-CimInstance command runs without delay.
            Start-Sleep -Seconds 5 
            $apps = Get-CimInstance -ClassName Win32_Product | Select-Object -Property Name, Version

            foreach($app in $apps){
                # Write-Output $app.Name
                if($app.Name -eq "Duo Authentication for Windows Logon x64"){
                    $success = $true
                }
            }
            if($success){
                Write-Output "Duo installed successfully!"
            }else{
                Write-Output "Installation not found. Trying again..."
                Invoke-Expression -Command $msiexecCommand
                Write-Output "Installation command executed."
            }
        }
        if(!$success -and ($iters -eq $maxIters)){ Write-Output "Sorry. I did not succeed after $maxIters attempts and I gave up." }

    }
    catch {
        # Capture and log any errors
        Write-Output "Failed to execute msiexec command."
        $_.Exception.Message | Out-File -FilePath $logPath
    }
} -ArgumentList $msiexecCommand, $logPath

# Delete Script folder on remote host
Invoke-Command -ComputerName $hostname -ScriptBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$remoteFolderPath
    )

    Write-Host "Received path value on remote computer: $remoteFolderPath"

    try {
        # Extract parent folder and subfolder names
        $parentFolderPath = (Get-Item -Path $remoteFolderPath).Parent.FullName
        $subfolderName = (Get-Item -Path $remoteFolderPath).Name

        Write-Host "Parent folder: $parentFolderPath"
        Write-Host "Subfolder: $subfolderName"

        # Ensure the subfolder exists
        if (-not (Test-Path -Path $remoteFolderPath)) {
            Write-Host "The folder $remoteFolderPath does not exist; creating it for testing."
            New-Item -ItemType Directory -Path $remoteFolderPath -Force | Out-Null
        }

        # Safely remove only the specified subfolder
        if ((Test-Path -Path $remoteFolderPath) -and ($subfolderName -eq "Script")) {
            Remove-Item -Path $remoteFolderPath -Force -Recurse
            Write-Host "Folder deleted successfully: $remoteFolderPath"
        } else {
            Write-Host "The folder to delete does not match 'Script'. Skipping deletion."
        }
    }
    catch {
        Write-Error "Error occurred: $($_.Exception.Message)"
        Write-Host "Exception details: $($_)"
    }
} -ArgumentList $folderPath

#Check Connectivity and use PsExec to Disable PowerShell connection on remote host
try {
    # Test network connectivity
    if (Test-Connection -ComputerName $hostname -Count 2 -Quiet) {
        Write-Host "Computer $hostname is reachable"
        
        # Attempt PsExec with full diagnostic output
        $result = cmd /c "C:\Tools\Script\PsExec.exe" "\\$hostname" -s powershell.exe -ExecutionPolicy Bypass -Command "Stop-Service WinRM" 2>&1 | Out-Null
        
        Write-Host "WinRM service stop attempted on $hostname"
    } else {
        Write-Error "Cannot reach computer $hostname"
    }
} catch {
    Write-Error "Error occurred: $_"
}

# Delete the local Script folder
try {
    # Remove the Script folder
    if (Test-Path -Path $folderPath) {
        Remove-Item -Path $folderPath -Recurse -Force
        Write-Host "Script folder deleted successfully."
    }
}
catch {
    Write-Error "Failed to delete Script folder: $_"
}
