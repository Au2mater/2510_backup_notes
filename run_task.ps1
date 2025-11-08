# Dot-source shared env loader (if available) and load .env
$helper = Join-Path $PSScriptRoot 'lib\env.ps1'
if (Test-Path $helper) { . $helper } else { Write-Verbose "Load-DotEnv helper not found: $helper" }

$envPath = Join-Path $PSScriptRoot '.env'
Load-DotEnv -Path $envPath

if ($null -ne (Get-Variable -Name 'logPath' -Scope Script -ErrorAction SilentlyContinue)) {
	$logPath = (Get-Variable -Name 'logPath' -Scope Script -ValueOnly)
} else {
	$logPath = Join-Path $PSScriptRoot 'backup_notes.log'
}

$taskName = "GitBackupNotesTask-User-${env:USERNAME}"

Start-ScheduledTask -TaskName $taskName
Get-ScheduledTaskInfo -TaskName $taskName   # shows LastRunTime & LastTaskResult
# wait two seconds to allow the task to start and write to the log
Start-Sleep -Seconds 2
Get-Content $logPath -Tail 100