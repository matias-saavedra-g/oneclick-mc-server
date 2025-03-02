# Configuration - Adjust these values if needed
$MINECRAFT_VERSION_MANIFEST_URL = "https://piston-meta.mojang.com/mc/game/version_manifest.json"
$JAVA_ARGS = "-Xmx4G -Xms1G"
$SERVER_JAR = "server.jar"
$BACKUP_FOLDER = "backups"
$AUTO_RESTART = $true
$VERSION_TYPE = "release"
$MAX_BACKUPS = 5
$LOGS_FOLDER = "session_logs"
$MAX_LOGS = 10

# Add log saving function
function Save-SessionLog {
    param (
        [string]$LogContent,
        [string]$ExitReason = "normal"
    )
    
    # Create logs directory if it doesn't exist
    if (-not (Test-Path $LOGS_FOLDER)) {
        New-Item -ItemType Directory -Path $LOGS_FOLDER | Out-Null
    }
    
    # Generate log filename with timestamp
    $timestamp = Get-Date -Format "yyyy.MM.dd_HH.mm.ss"
    $logFile = "$LOGS_FOLDER\server_session_$timestamp"
    
    # Add exit reason to filename if it's not a normal exit
    if ($ExitReason -ne "normal") {
        $logFile += "_$ExitReason"
    }
    $logFile += ".log"
    
    # Add header to log file
    $headerInfo = @"
=============================================
  MINECRAFT SERVER SESSION LOG
  Server Version: $($currentVersion)
  Session Start: $(Get-Date)
  Exit Reason: $ExitReason
=============================================

"@
    
    # Save log content
    $headerInfo + $LogContent | Out-File -FilePath $logFile
    
    Write-Host "Session log saved to: $logFile" -ForegroundColor Cyan
    
    # Clean up old logs, keeping only the last MAX_LOGS
    $oldLogs = Get-ChildItem "$LOGS_FOLDER\server_session_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $MAX_LOGS
    foreach ($log in $oldLogs) {
        Remove-Item $log.FullName -ErrorAction SilentlyContinue
    }
}

# Functions
function Get-LatestVersion {
    try {
        $versionData = Invoke-RestMethod -Uri $MINECRAFT_VERSION_MANIFEST_URL -TimeoutSec 10
        $latestVersion = $versionData.versions | Where-Object { $_.type -eq $VERSION_TYPE } | Select-Object -First 1
        return $latestVersion.id
    }
    catch {
        return $null
    }
}

function Get-CurrentVersion {
    if (Test-Path "version.json") {
        try {
            $versionData = Get-Content "version.json" | ConvertFrom-Json
            return $versionData.id
        }
        catch {
            return "unknown"
        }
    }
    else {
        return "unknown"
    }
}

function Download-ServerJar {
    param (
        [string]$latestVersion
    )
    
    try {
        # Get version manifest for latest release
        $versionData = Invoke-RestMethod -Uri $MINECRAFT_VERSION_MANIFEST_URL -TimeoutSec 10
        $versionUrl = ($versionData.versions | Where-Object { $_.id -eq $latestVersion }).url
        
        if (-not $versionUrl) {
            Write-Host "ERROR: Failed to get version URL" -ForegroundColor Red
            return $false
        }
        
        # Download version JSON
        $versionInfo = Invoke-RestMethod -Uri $versionUrl -TimeoutSec 10
        $versionInfo | ConvertTo-Json -Depth 10 | Out-File "version.json"
        
        # Extract server download URL
        $serverUrl = $versionInfo.downloads.server.url
        
        if (-not $serverUrl) {
            Write-Host "ERROR: Failed to extract server download URL" -ForegroundColor Red
            return $false
        }
        
        # Download the server jar
        Write-Host "Downloading from: $serverUrl"
        Invoke-WebRequest -Uri $serverUrl -OutFile $SERVER_JAR -TimeoutSec 300
        
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to download server: $_" -ForegroundColor Red
        return $false
    }
}

function Backup-Server {
    $date = Get-Date -Format "yyyy.MM.dd_HH.mm.ss"
    
    Write-Host "Creating backup: $date..."
    
    if (Test-Path "world") {
        try {
            $backupPath = "$BACKUP_FOLDER\backup_$date.zip"
            Compress-Archive -Path "world", "server.properties" -DestinationPath $backupPath -ErrorAction Stop
            Write-Host "Backup created at $backupPath"
            
            # Clean up old backups, keeping only the last MAX_BACKUPS
            $backups = Get-ChildItem "$BACKUP_FOLDER\backup_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $MAX_BACKUPS
            foreach ($backup in $backups) {
                Remove-Item $backup.FullName -ErrorAction SilentlyContinue
            }
            
            return $true
        }
        catch {
            Write-Host "ERROR: Backup creation failed: $_" -ForegroundColor Red
            Write-Host "Press any key to continue anyway..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $false
        }
    }
    else {
        Write-Host "No world folder found, skipping backup."
        return $true
    }
}

# Create backups directory if it doesn't exist
if (-not (Test-Path $BACKUP_FOLDER)) {
    New-Item -ItemType Directory -Path $BACKUP_FOLDER | Out-Null
}

# Create logs directory if it doesn't exist
if (-not (Test-Path $LOGS_FOLDER)) {
    New-Item -ItemType Directory -Path $LOGS_FOLDER | Out-Null
}

# Start transcript to capture all output
$transcriptFile = [System.IO.Path]::GetTempFileName()
Start-Transcript -Path $transcriptFile -Force | Out-Null

# Check if Java is available
try {
    $javaVersion = java -version
    if (-not $?) {
        throw "Java not found"
    }
}
catch {
    Write-Host "ERROR: Java is not installed or not found in PATH." -ForegroundColor Red
    Write-Host "Please install Java and make sure it's in your PATH."
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Transcript | Out-Null
    Save-SessionLog -LogContent (Get-Content $transcriptFile -Raw) -ExitReason "java_missing"
    Remove-Item $transcriptFile -Force -ErrorAction SilentlyContinue
    exit 1
}

# Main server loop
function Start-MinecraftServer {
    $global:currentVersion = "unknown"
    $exitReason = "normal"
    
    try {
        while ($true) {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "         MINECRAFT SERVER LAUNCHER" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            
            # Check for Minecraft server updates
            Write-Host "Checking for Minecraft server updates..."
            
            # Try to get latest version information, with error handling
            $latestVersion = Get-LatestVersion
            if (-not $latestVersion) {
                $exitReason = "version_check_failed"
                Write-Host "ERROR: Failed to retrieve latest version information." -ForegroundColor Red
                Write-Host "Check your internet connection and try again."
                Write-Host "Press any key to exit..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                break
            }
            
            if (-not (Test-Path $SERVER_JAR)) {
                Write-Host "No server jar found. Downloading latest version $latestVersion..."
                $downloadSuccess = Download-ServerJar -latestVersion $latestVersion
                
                if (-not $downloadSuccess) {
                    $exitReason = "download_failed"
                    Write-Host "ERROR: Failed to download server.jar" -ForegroundColor Red
                    Write-Host "Press any key to exit..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    break
                }
                
                Write-Host ""
                Write-Host "IMPORTANT: You need to manually accept the Minecraft EULA" -ForegroundColor Yellow
                Write-Host "Please edit the eula.txt file after first server run" -ForegroundColor Yellow
                Write-Host "and change 'eula=false' to 'eula=true' to accept the EULA." -ForegroundColor Yellow
                Write-Host ""
            }
            else {
                $global:currentVersion = Get-CurrentVersion
                if ($global:currentVersion -ne $latestVersion) {
                    Write-Host "New version found ($latestVersion). Current version: $global:currentVersion" -ForegroundColor Yellow
                    Write-Host "Creating backup before update..."
                    $backupSuccess = Backup-Server
                    
                    Write-Host "Updating server..."
                    $downloadSuccess = Download-ServerJar -latestVersion $latestVersion
                    
                    if (-not $downloadSuccess) {
                        $exitReason = "update_failed"
                        Write-Host "ERROR: Failed to update server.jar" -ForegroundColor Red
                        Write-Host "Press any key to exit..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        break
                    }
                    
                    $global:currentVersion = $latestVersion
                }
                else {
                    Write-Host "Already running latest version ($latestVersion)" -ForegroundColor Green
                }
            }
            
            # Check for EULA acceptance
            if (Test-Path "eula.txt") {
                $eulaContent = Get-Content "eula.txt"
                if (-not ($eulaContent -match "eula=true")) {
                    Write-Host ""
                    Write-Host "WARNING: It appears you have not accepted the Minecraft EULA." -ForegroundColor Yellow
                    Write-Host "Please edit the eula.txt file and change 'eula=false' to 'eula=true'" -ForegroundColor Yellow
                    Write-Host "to accept the EULA if you agree to its terms." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "You can find the EULA at: https://account.mojang.com/documents/minecraft_eula" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Press any key to continue anyway..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            
            Write-Host "Starting Minecraft server..." -ForegroundColor Cyan
            Write-Host -NoNewline "Server will start in  "
            
            # Countdown animation
            $countdownSeconds = 5
            for ($i = $countdownSeconds; $i -gt 0; $i--) {
                # Display current countdown with appropriate color
                if ($i -gt 3) {
                    $color = "Green"
                } elseif ($i -gt 1) {
                    $color = "Yellow"
                } else {
                    $color = "Red"
                }
                
                # Clear previous number and write new one
                Write-Host -NoNewline "`b$i" -ForegroundColor $color
                
                # Wait 1 second
                Start-Sleep -Seconds 1
            }
            
            Write-Host "`b0" -ForegroundColor Red
            Write-Host ""
            
            Write-Host "==========================================" -ForegroundColor Green
            Write-Host "         SERVER IS NOW RUNNING" -ForegroundColor Green
            Write-Host "==========================================" -ForegroundColor Green
            Write-Host "Type 'stop' in the console to safely shut down the server" -ForegroundColor Green
            Write-Host "==========================================" -ForegroundColor Green
            
            # Start the server and wait for it to exit
            $process = Start-Process -FilePath "java" -ArgumentList "$JAVA_ARGS -jar $SERVER_JAR nogui" -NoNewWindow -PassThru -Wait
            $exitCode = $process.ExitCode
            
            if ($exitCode -ne 0) {
                Write-Host "WARNING: Server exited with error code $exitCode" -ForegroundColor Yellow
                Write-Host "This may indicate a problem with the server or Java settings." -ForegroundColor Yellow
                Write-Host "If this is the first run, check if you need to accept the EULA." -ForegroundColor Yellow
                $exitReason = "server_error_$exitCode"
            }
            
            if ($AUTO_RESTART) {
                Write-Host "Server closed or crashed. Restarting in 10 seconds..." -ForegroundColor Yellow
                Write-Host "Press Ctrl+C now to stop auto-restart or any key to restart immediately."
                
                try {
                    # Wait either for 10 seconds or any key press
                    $secondsWaited = 0
                    while ($secondsWaited -lt 10) {
                        if ([Console]::KeyAvailable) {
                            $key = [Console]::ReadKey($true)
                            break
                        }
                        Start-Sleep -Milliseconds 500
                        $secondsWaited += 0.5
                    }
                    # Continue to next iteration = restart
                }
                catch {
                    # User likely pressed Ctrl+C
                    $exitReason = "manual_interrupt"
                    break
                }
            }
            else {
                Write-Host "Server closed or crashed." -ForegroundColor Yellow
                Write-Host "Press any key to exit..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                break
            }
        }
    }
    finally {
        # Save log regardless of how we exited
        Stop-Transcript | Out-Null
        Save-SessionLog -LogContent (Get-Content $transcriptFile -Raw) -ExitReason $exitReason
        Remove-Item $transcriptFile -Force -ErrorAction SilentlyContinue
    }
}

# Start the server
try {
    Start-MinecraftServer
}
catch {
    # Catch any unhandled exceptions
    Stop-Transcript | Out-Null
    Save-SessionLog -LogContent "UNHANDLED ERROR: $_`n`n$(Get-Content $transcriptFile -Raw)" -ExitReason "unhandled_error"
    Remove-Item $transcriptFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "A critical error occurred: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}