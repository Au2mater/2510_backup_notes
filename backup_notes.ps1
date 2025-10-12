# Path to the notes folder (Git repository)
$sourceFolder = "C:\Users\Bruger\OneDrive\Notes"

# Log file will live next to this script
$logPath = Join-Path $PSScriptRoot 'backup_notes.log'

function Log {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    try {
        Add-Content -Path $logPath -Value $line
    } catch {
        # If logging to file fails, still write to host so the user sees something
        Write-Host "${timestamp} [ERROR] Failed to write log: $($_.Exception.Message)"
    }
    Write-Host $line
}

# Rotate log if it grows too large (simple rotation)
try {
    if (Test-Path $logPath) {
        $size = (Get-Item $logPath).Length
        if ($size -gt 5MB) {
            $archiveName = "backup_notes_$((Get-Date).ToString('yyyyMMddHHmmss')).log"
            $archivePath = Join-Path $PSScriptRoot $archiveName
            Move-Item -Path $logPath -Destination $archivePath -ErrorAction SilentlyContinue
            Log 'INFO' "Rotated log to $archiveName"
        }
    }
} catch {
    Log 'WARN' "Log rotation failed: $($_.Exception.Message)"
}

Log 'INFO' "Starting backup script. Script path: $PSScriptRoot"

try {
    # Don't change the current working directory. Verify the repo path exists and warn if .git is missing.
    if (-not (Test-Path $sourceFolder)) {
        Log 'ERROR' "Source folder not found: $($sourceFolder)"
        Exit 1
    }
    if (-not (Test-Path (Join-Path $sourceFolder '.git'))) {
        Log 'WARN' "No .git directory detected in $($sourceFolder). Git commands may fail or operate on a bare repo."
    }
    Log 'INFO' "Using repository path: $($sourceFolder)"
} catch {
    Log 'ERROR' "Failed to validate repository path $($sourceFolder): $($_.Exception.Message)"
    Exit 1
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
    Exit $addExit
}

# Check if any changes are in the index (staged)
$diffOutput = & git -C $sourceFolder diff --cached --name-only 2>&1
$diffExit = $LASTEXITCODE
if ($diffExit -ne 0) {
    Log 'ERROR' "git diff --cached failed: $($diffOutput -join ' | ')"
    Exit $diffExit
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
        Exit $commitExit
    }

    $logCmdPush = "git -C $sourceFolder push"
    Log 'INFO' "Running: $logCmdPush"
    $pushOutput = & git -C $sourceFolder push 2>&1
    $pushExit = $LASTEXITCODE
    if ($pushOutput) { Log 'DEBUG' "git push output: $($pushOutput -join ' | ')" }
    if ($pushExit -ne 0) {
        Log 'ERROR' "git push failed with exit code $pushExit"
        Exit $pushExit
    }

    Log 'INFO' "Backup completed successfully."
} else {
    Log 'INFO' "No new changes to commit."
}
