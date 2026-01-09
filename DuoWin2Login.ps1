param(
    [Parameter(Mandatory=$false)]
    [string]$hostname
)

# Define total steps and initialize current step
[int]$totalSteps = 17
[int]$currentStep = 0

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

function Get-ProgressivePercentage {
    param(
        [int]$TotalSteps,
        [int]$CurrentStep
    )
    
    $baseIncrement = 100 / $TotalSteps
    $currentPercentage = [Math]::Min([Math]::Floor($baseIncrement * $CurrentStep), 100)
    return $currentPercentage
}

function Write-LogMessage {
    param(
        [string]$Message,
        [switch]$IsError,
        [switch]$Loading,
        [int]$ProgressPercentage = -1,
        [switch]$QuietSuccess  # Suppress success output on console
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
        Write-Host ""
    }
    
    if ($ProgressPercentage -ne -1) {
        Write-ProgressBar -Task $Message -Percentage $ProgressPercentage
    }

    if ($IsError) {
        Write-Host "[X] $logMessage" -ForegroundColor Red
        Add-Content -Path "$env:TEMP\DuoInstallLog.txt" -Value "ERROR: $logMessage"
    } elseif (-not $QuietSuccess) {
        Write-Host "[+] $logMessage" -ForegroundColor Green
        Add-Content -Path "$env:TEMP\DuoInstallLog.txt" -Value "SUCCESS: $logMessage"
    } else {
        # Log to file only
        Add-Content -Path "$env:TEMP\DuoInstallLog.txt" -Value "SUCCESS: $logMessage"
    }
}

Write-LogMessage -Message "Starting Duo Windows Logon installation for $hostname" -QuietSuccess

# Step 1: Start PsExec download and extraction
$script:currentStep++
$folderPath = "C:\Tools\Script"
$psToolsZipPath = Join-Path $folderPath "PSTools.zip"
$psExecPath = Join-Path $folderPath "PsExec.exe"

$psexecJob = Start-Job -ScriptBlock {
    param($folderPath, $psToolsZipPath, $psExecPath)
    function Write-LogMessage {
        param([string]$Message, [switch]$IsError)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        if ($IsError) { Write-Output "ERROR: $logMessage" } else { Write-Output "SUCCESS: $logMessage" }
    }
    try {
        if (!(Test-Path -Path $folderPath)) { New-Item -ItemType Directory -Path $folderPath | Out-Null }
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

# Step 2: Validate hostname
$script:currentStep++
if ([string]::IsNullOrWhiteSpace($hostname)) {
    $hostname = Read-Host "Please enter the hostname"
}

if ([string]::IsNullOrWhiteSpace($hostname)) {
    Write-LogMessage -Message "Hostname cannot be empty. Script cannot continue." -IsError
    exit
}

# Step 3: Prompt for Duo version selection
$script:currentStep++
Write-Host "Select Duo version to install:" -ForegroundColor Cyan
Write-Host "1) Latest version (default)" -ForegroundColor Green
Write-Host "2) Version 4.3.1" -ForegroundColor Green
Write-Host "Press 1, 2, or wait 3 seconds for default..." -ForegroundColor Yellow
$timeoutSeconds = 3
$startTime = Get-Date
$choice = $null
while (((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true).Key
        if ($key -eq 'D1' -or $key -eq 'NumPad1') { $choice = '1'; break }
        if ($key -eq 'D2' -or $key -eq 'NumPad2') { $choice = '2'; break }
        if ($key -eq 'Enter') { $choice = 'default'; break }
    }
    Start-Sleep -Milliseconds 100
}
if ($choice -eq $null) {
    Write-Host "Timeout reached. Using default (latest version)." -ForegroundColor Yellow
    $choice = 'default'
}
if ($choice -eq '2') {
    $duoVersion = "4.3.1"
    Write-LogMessage -Message "User selected Duo version: 4.3.1" -QuietSuccess
} else {
    $duoVersion = $null
    Write-LogMessage -Message "User selected Duo version: latest (default)" -QuietSuccess
}

# Step 4: Wait for PsExec job
$script:currentStep++
Write-LogMessage -Message "Waiting for PsExec preparation to complete..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
$jobResult = Wait-Job -Job $psexecJob | Receive-Job
foreach ($line in $jobResult) {
    if ($line -match "ERROR: (.*)") {
        Write-LogMessage -Message $matches[1] -IsError
        Remove-Job -Job $psexecJob -Force
        exit
    } elseif ($line -match "SUCCESS: (.*)") {
        Write-LogMessage -Message $matches[1] -QuietSuccess
    }
}
Remove-Job -Job $psexecJob -Force

if (-not (Test-Path $psExecPath)) {
    Write-LogMessage -Message "PsExec.exe not found at $psExecPath after job completion." -IsError
    exit
}

# Step 5: Verify network connectivity
$script:currentStep++
Write-LogMessage -Message "Verifying network uplink to $hostname..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
if (!(Test-Connection -ComputerName $hostname -Count 2 -Quiet)) {
    Write-LogMessage -Message "Cannot reach computer $hostname" -IsError
    exit
}

# Step 6: Load environment variables
$script:currentStep++
Write-LogMessage -Message "Initializing NEON_ENV protocols..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
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
    } catch {
        Write-LogMessage -Message "Error reading .env file: $_" -IsError
    }
}

if ([string]::IsNullOrWhiteSpace($env:IKEY) -or [string]::IsNullOrWhiteSpace($env:SKEY) -or [string]::IsNullOrWhiteSpace($env:DHOST)) {
    Write-LogMessage -Message "Missing required Duo authentication environment variables." -IsError
    exit
}

function Get-LatestDuoVersion {
    $fallbackVersion = "5.0.0"
    try {
        Write-LogMessage -Message "Fetching the latest Duo version from https://duo.com/docs/rdp-notes..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
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
                Write-LogMessage -Message "Latest Duo version found: $latestVersion" -QuietSuccess
                return $latestVersion
            }
        }
        
        Write-LogMessage -Message "Could not find version. Using fallback: $fallbackVersion" -IsError
        return $fallbackVersion
    } catch {
        Write-LogMessage -Message "Failed to fetch Duo version: $_" -IsError
        return $fallbackVersion
    }
}

if (-not $duoVersion) {
    $duoVersion = Get-LatestDuoVersion
}

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

# Step 7: Create remote folder
$script:currentStep++
Write-LogMessage -Message "Initializing remote filesystem..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
$cmd = "cmd /c if not exist `"$remoteFolderPath`" mkdir `"$remoteFolderPath`""
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $result = Invoke-Expression $cmd 2>&1 | Out-String
} else {
    $rawResult = & $psExecPath "\\$hostname" -s -accepteula cmd.exe /c $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $result = $rawResult -replace "(?s).*cmd.exe exited on.*with error code 0.*$", ""
        $result = $result.Trim()
        if (-not $result) { $result = "Command completed successfully." }
        Write-LogMessage -Message "Remote folder created or already exists." -QuietSuccess
    } else {
        $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
        Write-LogMessage -Message "Failed to create remote folder: $result" -IsError
        exit
    }
}

# Step 8: Uninstall existing Duo
$script:currentStep++
Write-LogMessage -Message "Purging old Duo cyberware..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
$uninstallCmd = @"
`$ErrorActionPreference = 'Stop'
try {
`$duoProducts = Get-CimInstance -ClassName Win32_Product | Where-Object { `$_.Name -eq 'Duo Authentication for Windows Logon x64' -or `$_.Name -like '*Duo Authentication*' }
    if (`$duoProducts) {
        foreach (`$product in `$duoProducts) {
            `$productCode = `$product.IdentifyingNumber
            `$uninstallResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"`$productCode`"` /quiet /norestart" -Wait -PassThru
            Write-Output "Uninstalling `$(`$product.Name): Exit Code `$(`$uninstallResult.ExitCode)"
        }
    } else {
        Write-Output 'No Duo installation found to uninstall.'
    }
} catch {
    Write-Output "Error during uninstall: `$_"
    exit 1
}
"@

if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $result = Invoke-Expression $uninstallCmd 2>&1 | Out-String
} else {
    $rawResult = & $psExecPath "\\$hostname" -s -accepteula powershell.exe -Command $uninstallCmd 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $result = $rawResult -replace "(?s).*powershell.exe exited on.*with error code 0.*$", ""
        $result = $result.Trim()
        if (-not $result) { $result = "Command completed successfully." }
    } else {
        $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
    }
}
Write-LogMessage -Message "Uninstall attempt output: $result" -QuietSuccess
if ($result -match "Error during uninstall" -or $LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Uninstallation failed: $result" -IsError
    exit
}

# Step 9: Verify uninstall
$script:currentStep++
Write-LogMessage -Message "Verifying no residual Duo signatures..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
function Test-DuoInstallation {
    $duoProducts = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -eq 'Duo Authentication for Windows Logon x64' -or $_.Name -like '*Duo Authentication*' }
    if ($duoProducts) { return ($duoProducts | ForEach-Object { $_.Name }) -join ', ' }
    return ''
}

if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $verifyResult = Test-DuoInstallation
} else {
    try {
        $verifyCmd = ${function:Test-DuoInstallation}.ToString() + "`nTest-DuoInstallation"
        $rawVerifyResult = & $psExecPath "\\$hostname" -s powershell.exe -Command $verifyCmd 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $verifyResult = $rawVerifyResult -replace "(?s).*powershell.exe exited on.*with error code 0.*$", ""
            $verifyResult = $verifyResult.Trim()
            if (-not $verifyResult) { $verifyResult = "Command completed successfully." }
        } else {
            $verifyResult = "Verification command failed with exit code $LASTEXITCODE`n$rawVerifyResult"
        }
    } catch {
        Write-LogMessage -Message "Error during remote verification: $_" -IsError
        exit
    }
}

Write-LogMessage -Message "Verification output: '$verifyResult'" -QuietSuccess
if ($verifyResult.Trim() -and $verifyResult -ne "Command completed successfully.") {
    Write-LogMessage -Message "Duo still detected: $verifyResult" -IsError
    exit
} else {
    Write-LogMessage -Message "No existing Duo installation detected. Proceeding with install." -QuietSuccess
}

# Step 10: Download Duo ZIP
$script:currentStep++
Write-LogMessage -Message "Downloading Duo neural uplink..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
$downloadUrl = "https://dl.duosecurity.com/DuoWinLogon_MSIs_Policies_and_Documentation-$($duoVersion).zip"
$cmd = "powershell.exe -Command `"Invoke-WebRequest -Uri '$downloadUrl' -OutFile '$remoteFolderPath\DUO.ZIP'`""
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $result = Invoke-Expression $cmd 2>&1 | Out-String
} else {
    $rawResult = & $psExecPath "\\$hostname" -s -accepteula cmd.exe /c $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $result = $rawResult -replace "(?s).*cmd.exe exited on.*with error code 0.*$", ""
        $result = $result.Trim()
        if (-not $result) { $result = "Command completed successfully." }
    } else {
        $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
    }
}
Write-LogMessage -Message "Download output: $result" -QuietSuccess
if ($result -notmatch "Command completed successfully" -and $LASTEXITCODE -ne 0) {
    Write-LogMessage -Message "Failed to download Duo ZIP: $result" -IsError
    exit
}

# Step 11: Verify ZIP exists
$script:currentStep++
Write-LogMessage -Message "Scanning for uplink signature..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $retryCount = 0
    $maxRetries = 3
    do {
        $exists = Test-Path "$remoteFolderPath\DUO.ZIP"
        if ($exists) {
            $fileSize = (Get-Item "$remoteFolderPath\DUO.ZIP").Length
            $result = if ($fileSize -gt 0) { "ZIP_EXISTS (Size: $fileSize bytes)" } else { "ZIP file is empty" }
            break
        } else {
            $result = "ZIP file not found"
        }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 2
            Write-LogMessage -Message "Retrying ZIP verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
} else {
    $verifyCmd = @"
        if (Test-Path '$remoteFolderPath\DUO.ZIP') {
            `$size = (Get-Item '$remoteFolderPath\DUO.ZIP').Length
            if (`$size -gt 0) { Write-Output \"ZIP_EXISTS (Size: `$size bytes)\" }
            else { Write-Output 'ZIP file is empty' }
        } else { Write-Output 'ZIP file not found' }
"@
    $retryCount = 0
    $maxRetries = 3
    do {
        $rawResult = & $psExecPath "\\$hostname" -s -accepteula powershell.exe -Command $verifyCmd 2>&1 | Out-String
        Write-LogMessage -Message "Raw ZIP verification output: $rawResult" -QuietSuccess
        if ($LASTEXITCODE -eq 0) {
            $result = $rawResult -replace "(?s)^.*Starting powershell\.exe on $hostname[^\n]*\n", ""
            $result = $result -replace "(?s)\s*powershell\.exe exited on.*$", ""
            $result = $result.Trim()
            if ([string]::IsNullOrWhiteSpace($result)) { $result = "Command completed successfully but no output" }
        } else {
            $result = "Verification failed with exit code $LASTEXITCODE`n$rawResult"
            Write-LogMessage -Message "ZIP verification failed: $result" -IsError
            exit
        }
        Write-LogMessage -Message "Processed ZIP verification result: '$result'" -QuietSuccess
        if ($result -match "ZIP_EXISTS") { break }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 2
            Write-LogMessage -Message "Retrying ZIP verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
}
Write-LogMessage -Message "Verification result: '$result'" -QuietSuccess
if ($result -notmatch "ZIP_EXISTS") {
    Write-LogMessage -Message "ZIP file not found or invalid at $remoteFolderPath\DUO.ZIP after download: $result" -IsError
    exit
}
Write-LogMessage -Message "ZIP file downloaded and verified successfully." -QuietSuccess

# Step 12: Extract MSI from ZIP
$script:currentStep++
Write-LogMessage -Message "Extracting 64-bit cybernetic core..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead("$remoteFolderPath\DUO.ZIP")
        $msiEntry = $zip.Entries | Where-Object { $_.Name -eq "DuoWindowsLogon64.msi" }
        if ($msiEntry) {
            $dest = $msiPath
            $extractStream = [System.IO.File]::Create($dest)
            $entryStream = $msiEntry.Open()
            $entryStream.CopyTo($extractStream)
            $extractStream.Close()
            $entryStream.Close()
            $result = "Found MSI: DuoWindowsLogon64.msi"
        } else {
            $result = "DuoWindowsLogon64.msi not found in ZIP."
        }
        $zip.Dispose()
    } catch {
        $result = "Extraction error: $_"
    }
} else {
    $extractCommand = @"
        `$ErrorActionPreference = 'Stop'
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            `$zipPath = '$remoteFolderPath\DUO.ZIP'
            `$msiPath = '$msiPath'
            if (-not (Test-Path `$zipPath)) { Write-Output "ZIP file not found at `$zipPath"; exit 1 }
            `$zip = [System.IO.Compression.ZipFile]::OpenRead(`$zipPath)
            `$msiEntry = `$zip.Entries | Where-Object { `$_.Name -eq 'DuoWindowsLogon64.msi' }
            if (`$msiEntry) {
                `$extractStream = [System.IO.File]::Create(`$msiPath)
                `$entryStream = `$msiEntry.Open()
                `$entryStream.CopyTo(`$extractStream)
                `$extractStream.Close()
                `$entryStream.Close()
                Write-Output "Found MSI: DuoWindowsLogon64.msi"
            } else {
                Write-Output "DuoWindowsLogon64.msi not found in ZIP."
            }
            `$zip.Dispose()
        } catch {
            Write-Output "Extraction error: `$_"
            exit 1
        }
"@
    $retryCount = 0
    $maxRetries = 3
    do {
        $rawResult = & $psExecPath "\\$hostname" -s -accepteula powershell.exe -Command $extractCommand 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $result = $rawResult -replace "(?s).*powershell.exe exited on.*with error code 0.*$", ""
            $result = $result.Trim()
            if (-not $result) { $result = "Command completed successfully." }
            break
        } else {
            $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
        }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 2
            Write-LogMessage -Message "Retrying extraction (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
}
Write-LogMessage -Message "Extraction output: $result" -QuietSuccess
if ($result -notmatch "Found MSI: DuoWindowsLogon64.msi" -and $result -notmatch "Command completed successfully") {
    Write-LogMessage -Message "Failed to extract DuoWindowsLogon64.msi from ZIP: $result" -IsError
    exit
}
Write-LogMessage -Message "Using MSI: $msiName" -QuietSuccess

# Step 13: Verify MSI exists
$script:currentStep++
Write-LogMessage -Message "Confirming core integrity..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $retryCount = 0
    $maxRetries = 3
    do {
        $exists = Test-Path $msiPath
        $result = if ($exists) { "MSI_EXISTS" } else { "MSI file not found" }
        if ($result -match "MSI_EXISTS") { break }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 2
            Write-LogMessage -Message "Retrying MSI verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
} else {
    $verifyCmd = @"
        if (Test-Path '$msiPath') {
            Write-Output "MSI_EXISTS"
        } else {
            Write-Output "MSI file not found"
        }
"@
    $retryCount = 0
    $maxRetries = 3
    do {
        $rawResult = & $psExecPath "\\$hostname" -s -accepteula powershell.exe -Command $verifyCmd 2>&1 | Out-String
        Write-LogMessage -Message "Raw PsExec output: $rawResult" -QuietSuccess
        if ($LASTEXITCODE -eq 0) {
            $result = $rawResult -replace "(?s).*Starting powershell\.exe on $hostname.*?\n", ""
            $result = $result -replace "(?s)\s*powershell\.exe exited on.*$", ""
            $result = $result.Trim()
            if ([string]::IsNullOrWhiteSpace($result)) { $result = "Command completed successfully but no output" }
        } else {
            $result = "Verification failed with exit code $LASTEXITCODE`n$rawResult"
        }
        Write-LogMessage -Message "Processed MSI verification result: '$result'" -QuietSuccess
        if ($result -eq "MSI_EXISTS") { break }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 2
            Write-LogMessage -Message "Retrying MSI verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
}
Write-LogMessage -Message "MSI verification result: '$result'" -QuietSuccess
if ($result -ne "MSI_EXISTS") {
    Write-LogMessage -Message "MSI file not found at $msiPath on ${hostname}: $result" -IsError
    exit
}
Write-LogMessage -Message "MSI file confirmed at $msiPath" -QuietSuccess

# Step 14: Install Duo
$script:currentStep++
Write-LogMessage -Message "Installing Duo cyber-enhancement..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
$logPath = "C:\Tools\DuoInstall.log"
$msiexecCommand = "msiexec /i `"$msiPath`" IKEY=`"$ikey`" SKEY=`"$skey`" HOST=`"$dhost`" AUTOPUSH=`"$autopush`" FAILOPEN=`"$failopen`" SMARTCARD=`"$smartcard`" RDPONLY=`"$rdponly`" /qn /l*v `"$logPath`""
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $result = Invoke-Expression $msiexecCommand 2>&1 | Out-String
} else {
    $cmd = "cmd /c $msiexecCommand"
    $rawResult = & $psExecPath "\\$hostname" -s -h cmd.exe /c $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $result = $rawResult -replace "(?s).*cmd.exe exited on.*with error code 0.*$", ""
        $result = $result.Trim()
        if (-not $result) { $result = "Command completed successfully." }
        Write-LogMessage -Message "Duo installed successfully." -QuietSuccess
    } else {
        $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
        Write-LogMessage -Message "Installation failed with exit code $LASTEXITCODE. Check $logPath on $hostname for details." -IsError
        if (Test-Path $logPath) {
            $msiLogSnippet = Get-Content $logPath -Tail 20
            Write-LogMessage -Message "Last 20 lines of MSI log: $msiLogSnippet" -IsError
        }
        exit
    }
}

# Step 15: Verify installation
$script:currentStep++
Write-LogMessage -Message "Running system diagnostics..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
Start-Sleep -Seconds 5
$verifyCommand = @"
    try {
        `$product = Get-CimInstance -ClassName Win32_Product -ErrorAction Stop | Where-Object { `$_.Name -eq 'Duo Authentication for Windows Logon x64' }
        if (`$product) { Write-Output 'Duo installed successfully' }
        else { Write-Output 'Duo installation not found' }
    } catch {
        Write-Output \"Verification error: `$_\"

    }
"@
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    $retryCount = 0
    $maxRetries = 3
    do {
        $result = Invoke-Expression "powershell.exe -ExecutionPolicy Bypass -Command `$verifyCommand" 2>&1 | Out-String
        Write-LogMessage -Message "Raw local verification output: $result" -QuietSuccess
        $result = $result.Trim()
        if ($result -eq "Duo installed successfully") { break }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 3
            Write-LogMessage -Message "Retrying verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
} else {
    $retryCount = 0
    $maxRetries = 3
    do {
        $rawResult = & $psExecPath "\\$hostname" -s -accepteula powershell.exe -Command $verifyCommand 2>&1 | Out-String
        Write-LogMessage -Message "Raw remote verification output: $rawResult" -QuietSuccess
        if ($LASTEXITCODE -eq 0) {
            $result = $rawResult -replace "(?s)^.*Starting powershell\.exe on $hostname[^\n]*\n", ""
            $result = $result -replace "(?s)\s*powershell\.exe exited on.*$", ""
            $result = $result.Trim()
            if ([string]::IsNullOrWhiteSpace($result)) { $result = "Command completed successfully but no output" }
        } else {
            $result = "Verification failed with exit code $LASTEXITCODE`n$rawResult"
        }
        Write-LogMessage -Message "Processed verification result: '$result'" -QuietSuccess
        if ($result -eq "Duo installed successfully") { break }
        $retryCount++
        if ($retryCount -le $maxRetries) {
            Start-Sleep -Seconds 3
            Write-LogMessage -Message "Retrying verification (attempt $retryCount of $maxRetries)..." -QuietSuccess
        }
    } while ($retryCount -le $maxRetries)
}
Write-LogMessage -Message "Verification result: '$result'" -QuietSuccess
if ($result -ne "Duo installed successfully") {
    Write-LogMessage -Message "Verification failed: Duo not detected on ${hostname}: $result" -IsError
} else {
    Write-LogMessage -Message "Duo installation verified successfully." -QuietSuccess
}

# Step 16: Cleanup target folder
$script:currentStep++
Write-LogMessage -Message "Purging temporary data streams..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
if ($hostname -eq "localhost" -or $hostname -eq $env:COMPUTERNAME) {
    try {
        $filesToDelete = @("$remoteFolderPath\DUO.ZIP", "$remoteFolderPath\$msiName", $logPath)
        foreach ($file in $filesToDelete) {
            if (Test-Path $file) {
                Remove-Item -Path $file -Force -ErrorAction Stop
            }
        }
        if (Test-Path $remoteFolderPath) {
            Remove-Item -Path $remoteFolderPath -Recurse -Force -ErrorAction Stop
        }
        Write-LogMessage -Message "Cleanup completed successfully." -QuietSuccess
    } catch {
        Write-LogMessage -Message "Cleanup failed: $_" -IsError
        # Continue despite failure, as cleanup is non-critical
    }
} else {
    $cmd = "cmd /c del `"$remoteFolderPath\DUO.ZIP`" `"$remoteFolderPath\$msiName`" `"$logPath`" /f /q 2>nul & rmdir /s /q `"$remoteFolderPath`""
    $rawResult = & $psExecPath "\\$hostname" -s -accepteula -n 30 cmd.exe /c $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $result = $rawResult -replace "(?s).*cmd.exe exited on.*with error code 0.*$", ""
        $result = $result.Trim()
        if (-not $result) { $result = "Command completed successfully." }
        Write-LogMessage -Message "Cleanup completed successfully: $result" -QuietSuccess
    } else {
        $result = "Command failed with exit code $LASTEXITCODE`n$rawResult"
        Write-LogMessage -Message "Cleanup failed, but continuing: $result" -IsError
    }
}

# Step 17: Cleanup local folder
$script:currentStep++
Write-LogMessage -Message "Resetting local node..." -Loading -ProgressPercentage (Get-ProgressivePercentage -TotalSteps $totalSteps -CurrentStep $currentStep)
try {
    if (Test-Path -Path $folderPath) {
        Remove-Item -Path $folderPath -Recurse -Force
        Write-LogMessage -Message "Local Script folder deleted successfully." -QuietSuccess
    }
} catch {
    Write-LogMessage -Message "Failed to delete local Script folder: $_" -IsError
}

Write-LogMessage -Message "Duo Logon installation completed for $hostname" -QuietSuccess