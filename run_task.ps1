Start-ScheduledTask -TaskName 'GitBackupNotesTask'
Get-ScheduledTaskInfo -TaskName 'GitBackupNotesTask'   # shows LastRunTime & LastTaskResult
Get-Content .\backup_notes.log -Tail 100