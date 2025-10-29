# List of notes folders (Git repositories)
$sourceFolders = @(
    "C:\Users\Bruger\OneDrive\Notes",
    "C:\Users\Bruger\OneDrive\Notes_Work"
)

# Log file will live next to this script. Use $PSScriptRoot so path is correct when scheduled.
$logDir = $PSScriptRoot
$logPath = Join-Path $logDir 'backup_notes.log'

# Ensure the log directory exists (Task Scheduler may start with a different working dir)
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Log {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    try {
        Add-Content -Path $logPath -Value $line -ErrorAction Stop
    } catch {
        # If logging to file fails, write a clear error and try a fallback to TEMP
        $err = $_.Exception.Message
        $fallback = Join-Path $env:TEMP "backup_notes_fallback.log"
    $fallbackLine = "$timestamp [FALLBACK] Failed to write ${logPath}: ${err} -- Fallback log entry"
        try {
            Add-Content -Path $fallback -Value $fallbackLine -ErrorAction Stop
            Write-Host "$fallbackLine (wrote to $fallback)"
        } catch {
            Write-Host "$timestamp [ERROR] Failed to write fallback log as well: $($_.Exception.Message)"
        }
        Write-Host "${timestamp} [ERROR] Failed to write log: $err"
    }
    Write-Host $line
}

# Rotate log if it grows too large (simple rotation)
try {
    if (Test-Path $logPath) {
        $size = (Get-Item $logPath).Length
        if ($size -gt 5MB) {
            $archiveName = "backup_notes_$((Get-Date).ToString('yyyyMMddHHmmss')).log"
            $archivePath = Join-Path $logDir $archiveName
            Move-Item -Path $logPath -Destination $archivePath -ErrorAction SilentlyContinue
            Log 'INFO' "Rotated log to $archiveName"
        }
    }
} catch {
    Log 'WARN' "Log rotation failed: $($_.Exception.Message)"
}

# Startup diagnostics to help Task Scheduler troubleshooting
Log 'INFO' "Starting backup script. Script path: $PSScriptRoot"
Log 'DEBUG' "Current user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Log 'DEBUG' "PWD: $(Get-Location)"
Log 'DEBUG' "Process: $([System.Diagnostics.Process]::GetCurrentProcess().ProcessName) (Id=$([System.Diagnostics.Process]::GetCurrentProcess().Id))"
Log 'DEBUG' "Env: USERPROFILE=$env:USERPROFILE; TEMP=$env:TEMP; ONE_DRIVE=$env:OneDrive; ProgramData=$env:ProgramData"


# Loop through each source folder
foreach ($sourceFolder in $sourceFolders) {
    try {
        # Don't change the current working directory. Verify the repo path exists and warn if .git is missing.
        if (-not (Test-Path $sourceFolder)) {
            Log 'ERROR' "Source folder not found: $($sourceFolder)"
            continue
        }
        if (-not (Test-Path (Join-Path $sourceFolder '.git'))) {
            Log 'WARN' "No .git directory detected in $($sourceFolder). Git commands may fail or operate on a bare repo."
        }
        Log 'INFO' "Using repository path: $($sourceFolder)"
    } catch {
        Log 'ERROR' "Failed to validate repository path $($sourceFolder): $($_.Exception.Message)"
        continue
    }


    # Fetch and pull latest changes before backup
    $logCmdFetch = "git -C $sourceFolder fetch --all"
    Log 'INFO' "Running: $logCmdFetch"
    $fetchOutput = & git -C $sourceFolder fetch --all 2>&1
    $fetchExit = $LASTEXITCODE
    if ($fetchOutput) { Log 'DEBUG' "git fetch output: $($fetchOutput -join ' | ')" }
    if ($fetchExit -ne 0) {
        Log 'ERROR' "git fetch failed with exit code $fetchExit"
        continue
    }

    $logCmdPull = "git -C $sourceFolder pull"
    Log 'INFO' "Running: $logCmdPull"
    $pullOutput = & git -C $sourceFolder pull 2>&1
    $pullExit = $LASTEXITCODE
    if ($pullOutput) { Log 'DEBUG' "git pull output: $($pullOutput -join ' | ')" }
    if ($pullExit -ne 0) {
        Log 'ERROR' "git pull failed with exit code $pullExit"
        continue
    }

    # Create the commit message with date and time
    $dateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMessage = "backup $dateTime"
    Log 'INFO' "Commit message: $commitMessage"

    # Stage changes
    $logCmdAdd = "git -C $sourceFolder add ."
    Log 'INFO' "Running: $logCmdAdd"
    $addOutput = & git -C $sourceFolder add . 2>&1
    $addExit = $LASTEXITCODE
    if ($addOutput) { Log 'DEBUG' "git add output: $($addOutput -join ' | ')" }
    if ($addExit -ne 0) {
        Log 'ERROR' "git add failed with exit code $addExit"
        continue
    }

    # Check if any changes are in the index (staged)
    $diffOutput = & git -C $sourceFolder diff --cached --name-only 2>&1
    $diffExit = $LASTEXITCODE
    if ($diffExit -ne 0) {
        Log 'ERROR' "git diff --cached failed: $($diffOutput -join ' | ')"
        continue
    }

    if ($diffOutput -and $diffOutput.Trim() -ne '') {
        Log 'INFO' "Staged files: $diffOutput"

        $logCmdCommit = "git -C $sourceFolder commit -m '$commitMessage'"
        Log 'INFO' "Running: $logCmdCommit"
        $commitOutput = & git -C $sourceFolder commit -m $commitMessage 2>&1
        $commitExit = $LASTEXITCODE
        if ($commitOutput) { Log 'DEBUG' "git commit output: $($commitOutput -join ' | ')" }
        if ($commitExit -ne 0) {
            Log 'ERROR' "git commit failed with exit code $commitExit"
            continue
        }

        $logCmdPush = "git -C $sourceFolder push"
        Log 'INFO' "Running: $logCmdPush"
        $pushOutput = & git -C $sourceFolder push 2>&1
        $pushExit = $LASTEXITCODE
        if ($pushOutput) { Log 'DEBUG' "git push output: $($pushOutput -join ' | ')" }
        if ($pushExit -ne 0) {
            Log 'ERROR' "git push failed with exit code $pushExit"
            continue
        }

        Log 'INFO' "Backup completed successfully for $sourceFolder."
    } else {
        Log 'INFO' "No new changes to commit in $sourceFolder."
    }
}
