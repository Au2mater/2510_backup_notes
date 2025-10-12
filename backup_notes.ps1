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
    Set-Location $sourceFolder
    Log 'INFO' "Changed directory to $PWD"
} catch {
    Log 'ERROR' "Failed to change directory to $($sourceFolder): $($_.Exception.Message)"
    Exit 1
}

# Create the commit message with date and time
$dateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitMessage = "backup $dateTime"
Log 'INFO' "Commit message: $commitMessage"

# Stage changes
Log 'INFO' "Running: git add ."
$addOutput = & git add . 2>&1
$addExit = $LASTEXITCODE
if ($addOutput) { Log 'DEBUG' "git add output: $($addOutput -join ' | ')" }
if ($addExit -ne 0) {
    Log 'ERROR' "git add failed with exit code $addExit"
    Exit $addExit
}

# Check if any changes are in the index (staged)
$diffOutput = & git diff --cached --name-only 2>&1
$diffExit = $LASTEXITCODE
if ($diffExit -ne 0) {
    Log 'ERROR' "git diff --cached failed: $($diffOutput -join ' | ')"
    Exit $diffExit
}

if ($diffOutput -and $diffOutput.Trim() -ne '') {
    Log 'INFO' "Staged files: $diffOutput"

    Log 'INFO' "Running: git commit -m '$commitMessage'"
    $commitOutput = & git commit -m $commitMessage 2>&1
    $commitExit = $LASTEXITCODE
    if ($commitOutput) { Log 'DEBUG' "git commit output: $($commitOutput -join ' | ')" }
    if ($commitExit -ne 0) {
        Log 'ERROR' "git commit failed with exit code $commitExit"
        Exit $commitExit
    }

    Log 'INFO' "Running: git push"
    $pushOutput = & git push 2>&1
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
