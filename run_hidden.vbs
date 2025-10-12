Set WshShell = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & WScript.Arguments.Item(0) & """"
WshShell.Run cmd, 0, False