function Load-DotEnv {
    param(
        [string]$Path
    )
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $_ = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        if ($_ -match '^\s*#') { return }
        $parts = $_ -split '=', 2
        if ($parts.Count -ne 2) { return }
        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        # strip surrounding quotes if present
        if ($value -match '^"(.*)"$') { $value = $matches[1] }
        if ($value -match "^'(.*)'$") { $value = $matches[1] }
        try { Set-Variable -Name $name -Value $value -Scope Script -Force -ErrorAction SilentlyContinue } catch {}
    }
}

# This file is intended to be dot-sourced. Do not call Export-ModuleMember here
# because Export-ModuleMember is only valid inside a PowerShell module.
