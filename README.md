Automate folder backup to GitHub repository using PowerShell and Windows Task Scheduler

1. copy example.env to .env and update paths as needed
2. ensure git is installed and accessible in system PATH
3. ensure a git repository is initialized in the source folders to track changes and a remote GitHub repository is set up
4. schedule the schedule_script.ps1 in Windows Task Scheduler to run at desired intervals
5. to test the backup process, run run_task.ps1 after scheduling the task