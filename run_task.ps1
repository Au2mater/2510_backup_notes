$logPath = "C:\Users\Bruger\OneDrive\03_Resources\2510_backup_notes\backup_notes.log"  
Start-ScheduledTask -TaskName 'GitBackupNotesTask'
Get-ScheduledTaskInfo -TaskName 'GitBackupNotesTask'   # shows LastRunTime & LastTaskResult
# wait two seconds to allow the task to start and write to the log
Start-Sleep -Seconds 2
Get-Content $logPath -Tail 100