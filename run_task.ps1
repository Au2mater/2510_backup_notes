Start-ScheduledTask -TaskName 'GitBackupNotesTask'
Get-ScheduledTaskInfo -TaskName 'GitBackupNotesTask'   # shows LastRunTime & LastTaskResult
# wait two seconds to allow the task to start and write to the log
Start-Sleep -Seconds 2
Get-Content .\backup_notes.log -Tail 100