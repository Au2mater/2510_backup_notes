# Define the script path and task name
$scriptPath = "C:\Users\Bruger\OneDrive\03_Resources\2510_backup_notes\backup_notes.ps1"  # Update with your script path
$taskName = "GitBackupNotesTask"

function Test-IsElevated {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Delete the task if it already exists. If we don't have permission to delete it, warn and continue.
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Task '$taskName' already exists. Attempting to delete it..."
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "Existing task '$taskName' deleted."
        $existingTask = $null
    } catch {
        Write-Warning "Could not delete existing task '$taskName': $_"
        if (-not (Test-IsElevated)) {
            Write-Error "You are not running elevated and cannot delete or replace the existing task named '$taskName'. Re-run this script as Administrator to replace that task, or manually delete the task and re-run."
            exit 1
        } else {
            # If elevated but deletion still failed, rethrow
            throw
        }
    }
}

# Create the action to run PowerShell with the script
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File '$scriptPath'"

# Create triggers for the task
$triggerLogOn = New-ScheduledTaskTrigger -AtLogOn
# Create a trigger that starts at the next midnight and repeats every 2 hours.
# New-ScheduledTaskTrigger only accepts RepetitionInterval/Duration when using the -Once parameter set,
# so create an -Once trigger that starts at the next midnight and repeats for a long duration (e.g. 3650 days ~= 10 years).
$nextMidnight = (Get-Date).Date.AddDays(1)
$repetitionInterval = New-TimeSpan -Hours 2
$repetitionDuration = New-TimeSpan -Days 3650
$triggerHourly = New-ScheduledTaskTrigger -Once -At $nextMidnight -RepetitionInterval $repetitionInterval -RepetitionDuration $repetitionDuration

# Create settings for the task
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Register the scheduled task
try {
    $triggers = @($triggerLogOn, $triggerHourly) | Where-Object { $_ -ne $null }
    if (-not $triggers) { throw "No valid triggers to register." }

    if (Test-IsElevated) {
        # Register as SYSTEM when elevated
        Register-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -TaskName $taskName -User "SYSTEM" -RunLevel Highest -ErrorAction Stop
        Write-Host "Scheduled task '$taskName' created successfully (registered as SYSTEM)."
    } else {
        # Register for the current user when not elevated. Create a Principal for the current user and
        # register the task via New-ScheduledTask -> Register-ScheduledTask -InputObject which avoids needing
        # to provide credentials for Interactive logon type.
        try {
            $currentUserId = "${env:USERDOMAIN}\${env:USERNAME}"
            $principal = New-ScheduledTaskPrincipal -UserId $currentUserId -LogonType Interactive -RunLevel Limited
            $taskDefinition = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal
            Register-ScheduledTask -TaskName $taskName -InputObject $taskDefinition -ErrorAction Stop
            Write-Host "Scheduled task '$taskName' created successfully (registered for the current user: $currentUserId)."
            Write-Host "Note: To register the task as SYSTEM, re-run this script in an elevated PowerShell session."
        } catch {
            Write-Warning "Attempt to register task for current user failed: $_"
            Write-Error "If you need the task to run as SYSTEM or with highest privileges, re-run this script as Administrator and try again."
            exit 1
        }
    }
} catch {
    Write-Error "Failed to create scheduled task '$taskName': $_"
    throw
}
