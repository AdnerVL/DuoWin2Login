param(
    [Parameter(Mandatory=$false)]
    [string]$hostname
)

function Write-ProgressBar {
    param(
        [string]$Task,
        [int]$Percentage
    )
    $barLength = 30
    $filledLength = [math]::Floor($Percentage / 100 * $barLength)
    $bar = "[" + ("=" * $filledLength) + ("." * ($barLength - $filledLength)) + "]"
    
    Write-Host ("{0,-40} {1,4}% {2}" -f $Task, $Percentage, $bar) -ForegroundColor Magenta
}

# Logging function with Cyberpunk ASCII loading effect
function Write-LogMessage {
    param(
        [string]$Message,
        [switch]$IsError,
        [switch]$Loading,
        [int]$ProgressPercentage = -1
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    if ($Loading) {
        $asciiFrames = @(" * ", " * ", " * ", " * ", " * ", " * ")
        Write-Host -NoNewline "[NEON_BOOT] $Message " -ForegroundColor Cyan
        for ($i = 0; $i -lt 5; $i++) {
            $frame = $asciiFrames[$i % $asciiFrames.Length]
            Write-Host -NoNewline "$frame" -ForegroundColor Magenta
            Start-Sleep -Milliseconds 200
        }
        Write-Host "" # Newline after loading
    }
    
    if ($ProgressPercentage -ne -1) {
        Write-ProgressBar -Task $Message -Percentage $ProgressPercentage
    }

    if ($IsError) {
        Write-Host "[X] $logMessage" -ForegroundColor Red
        Add-Content -Path "$env:TEMP\DuoInstallLog.txt" -Value "ERROR: $logMessage"
    } else {
        Write-Host "[+] $logMessage" -ForegroundColor Green
        Add-Content -Path "$env:TEMP\DuoInstallLog.txt" -Value "SUCCESS: $logMessage"
    }
}

# Start PsExec download and extraction in the background
$folderPath = "C:\Tools\Script"
$psToolsZipPath = Join-Path $folderPath "PSTools.zip"
$psExecPath = Join-Path $folderPath "PsExec.exe"

$psexecJob = Start-Job -ScriptBlock {
    param($folderPath, $psToolsZipPath, $psExecPath)
    function Write-LogMessage {
        param([string]$Message, [switch]$IsError)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        if ($IsError) {
            Write-Output "ERROR: $logMessage"
        } else {
            Write-Output "SUCCESS: $logMessage"
        }
    }
    try {
        if (!(Test-Path -Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }
        Write-LogMessage -Message "Downloading PSTools.zip..."
        Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile $psToolsZipPath
        Write-LogMessage -Message "Extracting PsExec.exe..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($psToolsZipPath)
        $psExecEntry = $zip.Entries | Where-Object { $_.Name -eq "PsExec.exe" }
        if ($psExecEntry) {
            $entryStream = $psExecEntry.Open()
            $fileStream = [System.IO.File]::Create($psExecPath)
            $entryStream.CopyTo($fileStream)
            $fileStream.Close()
            $entryStream.Close()
            Write-LogMessage -Message "PsExec.exe extracted successfully."
        } else {
            Write-LogMessage -Message "PsExec.exe not found in the zip file." -IsError
            exit 1
        }
        $zip.Dispose()
    } catch {
        Write-LogMessage -Message "Failed to download or extract PSTools: $_" -IsError
        exit 1
    }
} -ArgumentList $folderPath, $psToolsZipPath, $psExecPath

# Validate hostname while PsExec downloads
if ([string]::IsNullOrWhiteSpace($hostname)) {
    $hostname = Read-Host "Please enter the hostname"
}

if ([string]::IsNullOrWhiteSpace($hostname)) {
    Write-LogMessage -Message "Hostname cannot be empty. Script cannot continue." -IsError
    exit
}

# Wait for PsExec job to complete and check results
Write-LogMessage -Message "Waiting for PsExec preparation to complete..." -Loading
$jobResult = Wait-Job -Job $psexecJob | Receive-Job
foreach ($line in $jobResult) {
    if ($line -match "ERROR: (.*)") {
        Write-LogMessage -Message $matches[1] -IsError
        Remove-Job -Job $psexecJob -Force
        exit
    } elseif ($line -match "SUCCESS: (.*)") {
        Write-LogMessage -Message $matches[1]
    }
}
Remove-Job -Job $psexecJob -Force

if (-not (Test-Path $psExecPath)) {
    Write-LogMessage -Message "PsExec.exe not found at $psExecPath after job completion." -IsError
    exit
}

# Verify network connectivity
Write-LogMessage -Message "Verifying network uplink to $hostname..." -Loading
if (!(Test-Connection -ComputerName $hostname -Count 2 -Quiet)) {
    Write-LogMessage -Message "Cannot reach computer $hostname" -IsError
    exit
}

# Load environment variables safely
Write-LogMessage -Message "Initializing NEON_ENV protocols..." -Loading
$envFile = Join-Path $PSScriptRoot ".env"
$env:IKEY = $null
$env:SKEY = $null
$env:DHOST = $null

if (Test-Path $envFile) {
    try {
        $envContent = Get-Content $envFile
        foreach ($line in $envContent) {
            $key, $value = $line -split '=', 2
            if ($key -and $value) {
                [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), 'Process')
            }
        }
    }
    catch {
        Write-LogMessage -Message "Error reading .env file: $_" -IsError
    }
}

# Validate required environment variables
if ([string]::IsNullOrWhiteSpace($env:IKEY) -or 
    [string]::IsNullOrWhiteSpace($env:SKEY) -or 
    [string]::IsNullOrWhiteSpace($env:DHOST)) {
    Write-LogMessage -Message "Missing required Duo authentication environment variables." -IsError
    exit
}

# Version detection function
function Get-LatestDuoVersion {
    $fallbackVersion = "5.0.0"
    try {
        Write-LogMessage -Message "Fetching the latest Duo version from https://duo.com/docs/rdp-notes..." -Loading
        $response = Invoke-WebRequest -Uri "https://duo.com/docs/rdp-notes" -UseBasicParsing
        $htmlContent = $response.Content
        
        $versionPatterns = @(
            'Duo Authentication for Windows Logon and RDP v(\d+\.\d+\.\d+)',
            'Duo Authentication for Windows Logon [vV]?(\d+\.\d+\.\d+)',
            'Version (\d+\.\d+\.\d+)',
            'Duo Authentication.*(\d+\.\d+\.\d+)'
        )
        
        foreach ($pattern in $versionPatterns) {
            if ($htmlContent -match $pattern) {
                $latestVersion = $matches[1]
                Write-LogMessage -Message "Latest Duo version found: $latestVersion"
                return $latestVersion
            }
        }
        
        Write-LogMessage -Message "Could not find version. Using fallback: $fallbackVersion" -IsError
        return $fallbackVersion
    }
    catch {
        Write-LogMessage -Message "Failed to fetch Duo version: $_" -IsError
        return $fallbackVersion
    }
}

$duoVersion = Get-LatestDuoVersion
$ikey = $env:IKEY
$skey = $env:SKEY
$dhost = $env:DHOST
$autopush = "#1"
$failopen = "#0"
$smartcard = "#0"
$rdponly = "#0"

$remoteFolderPath = "C:\Tools\Script"
$msiName = "DuoWindowsLogon64.msi"
$msiPath = "$remoteFolderPath\$msiName"

# Create remote folder
Write-LogMessage -Message "Initializing remote filesystem..." -Loading -ProgressPercentage 10
$cmd = "cmd /c if not exist `"$remoteFolderPath`" mkdir `"$remoteFolderPath`""
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Failed to create remote folder: $result" -IsError
    exit
}
Write-LogMessage -Message "Remote folder created or already exists."

# Uninstall existing Duo
Write-LogMessage -Message "Purging old Duo cyberware..." -Loading
$cmd = "wmic product where `"name='Duo Authentication for Windows Logon x64'`" call uninstall /nointeractive"
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
Write-LogMessage -Message "Attempted to uninstall existing Duo: $result"

# Download Duo ZIP
Write-LogMessage -Message "Downloading Duo neural uplink..." -Loading
$downloadUrl = "https://dl.duosecurity.com/DuoWinLogon_MSIs_Policies_and_Documentation-$($duoVersion).zip"
$cmd = "curl -o `"$remoteFolderPath\DUO.ZIP`" `"$downloadUrl`""
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
Write-LogMessage -Message "Download output: $result"
if ($LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Failed to download Duo ZIP: $result" -IsError
    exit
}

# Verify ZIP exists
Write-LogMessage -Message "Scanning for uplink signature..." -Loading
$cmd = "cmd /c if exist `"$remoteFolderPath\DUO.ZIP`" echo ZIP_EXISTS"
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
if ($result -notmatch "ZIP_EXISTS") {
    Write-LogMessage -Message "ZIP file not found at $remoteFolderPath\DUO.ZIP after download" -IsError
    exit
}
Write-LogMessage -Message "ZIP file downloaded successfully."

# Extract only DuoWindowsLogon64.msi from the ZIP on the remote host
Write-LogMessage -Message "Extracting 64-bit cybernetic core..." -Loading
$extractCommand = "Add-Type -AssemblyName System.IO.Compression.FileSystem; `$zip = [System.IO.Compression.ZipFile]::OpenRead('$remoteFolderPath\DUO.ZIP'); `$msiEntry = `$zip.Entries | Where-Object { `$_.Name -eq 'DuoWindowsLogon64.msi' }; if (`$msiEntry) { `$dest = '$msiPath'; `$extractStream = [System.IO.File]::Create(`$dest); `$entryStream = `$msiEntry.Open(); `$entryStream.CopyTo(`$extractStream); `$extractStream.Close(); `$entryStream.Close(); Write-Output 'Found MSI: DuoWindowsLogon64.msi' } else { Write-Output 'DuoWindowsLogon64.msi not found in ZIP.' }; `$zip.Dispose()"
$cmd = "powershell.exe -ExecutionPolicy Bypass -Command `"$extractCommand`""
$result = & $psExecPath "\\$hostname" -s -accepteula cmd.exe /c $cmd 2>&1 | Out-String
Write-LogMessage -Message "Extraction output: $result"
if ($LASTEXITCODE -ne 0 -or $result -notmatch "Found MSI: DuoWindowsLogon64.msi") {
    Write-LogMessage -Message "Failed to extract DuoWindowsLogon64.msi from ZIP: $result" -IsError
    exit
}
Write-LogMessage -Message "Using MSI: $msiName"

# Verify MSI exists remotely
Write-LogMessage -Message "Confirming core integrity..." -Loading
$cmd = "cmd /c if exist `"$msiPath`" echo MSI_EXISTS"
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
if ($result -notmatch "MSI_EXISTS") {
    Write-LogMessage -Message "MSI file not found at $msiPath on $hostname" -IsError
    exit
}
Write-LogMessage -Message "MSI file confirmed at $msiPath"

# Install Duo
Write-LogMessage -Message "Installing Duo cyber-enhancement..." -Loading
$logPath = "C:\Tools\DuoInstall.log"
$msiexecCommand = "msiexec /i `"$msiPath`" IKEY=`"$ikey`" SKEY=`"$skey`" HOST=`"$dhost`" AUTOPUSH=`"$autopush`" FAILOPEN=`"$failopen`" SMARTCARD=`"$smartcard`" RDPONLY=`"$rdponly`" /qn /l*v `"$logPath`""
$cmd = "cmd /c $msiexecCommand"
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
Write-LogMessage -Message "Installation output: $result"
if ($LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Installation failed. Check $logPath on $hostname for details: $result" -IsError
} else {
    Write-LogMessage -Message "Duo installed successfully."
}

# Verification step
Write-LogMessage -Message "Running system diagnostics..." -Loading
$verifyCommand = "powershell.exe -ExecutionPolicy Bypass -Command `"if (Get-CimInstance -ClassName Win32_Product | Where-Object { `$_.Name -eq 'Duo Authentication for Windows Logon x64' }) { Write-Output 'Duo installed successfully.' } else { Write-Output 'Duo installation not found.' }`""
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $verifyCommand 2>&1 | Out-String
Write-LogMessage -Message "Verification result: $result"
if ($result -notmatch "Duo installed successfully") {
    Write-LogMessage -Message "Verification failed: Duo not detected on $hostname" -IsError
}

# Cleanup remote folder with timeout and pre-deletion
Write-LogMessage -Message "Purging temporary data streams..." -Loading
# Pre-delete specific files to avoid locks
$cmd = "cmd /c del `"$remoteFolderPath\DUO.ZIP`" `"$remoteFolderPath\$msiName`" `"$logPath`" /f /q 2>nul"
$result = & $psExecPath "\\$hostname" -s cmd.exe /c $cmd 2>&1 | Out-String
Write-LogMessage -Message "Pre-deletion of files: $result"
# Clean up the folder with a 30-second timeout
$cmd = "cmd /c rmdir /s /q `"$remoteFolderPath`""
$result = & $psExecPath "\\$hostname" -s -n 30 cmd.exe /c $cmd 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Cleanup failed, but continuing: $result" -IsError
} else {
    Write-LogMessage -Message "Attempted to clean up remote folder: $result"
}

# Cleanup local folder
Write-LogMessage -Message "Resetting local node..." -Loading
try {
    if (Test-Path -Path $folderPath) {
        Remove-Item -Path $folderPath -Recurse -Force
        Write-LogMessage -Message "Local Script folder deleted successfully."
    }
}
catch {
    Write-LogMessage -Message "Failed to delete local Script folder: $_" -IsError
}