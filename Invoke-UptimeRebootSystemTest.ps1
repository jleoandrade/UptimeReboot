# Run through SCCM: Software Library > Scripts > Create Script (approve it) > right-click the device > Run Script.
# Runs as SYSTEM, exactly like the deployment type. Safe: Install-UptimeReboot.ps1 never restarts the computer.
# Output is kept short because Run Script shows a limited amount of text.

$appEnforceLog = Get-Content -Path 'C:\Windows\CCM\Logs\AppEnforce.log' -Raw
$workingDirectory = ([regex]::Matches($appEnforceLog, 'Working directory (.+?)\]LOG\]') | Select-Object -Last 1).Groups[1].Value
if (-not $workingDirectory -or -not (Test-Path -LiteralPath (Join-Path $workingDirectory 'Install-UptimeReboot.ps1'))) {
    "STOP: Install-UptimeReboot.ps1 not found in '$workingDirectory'"
    return
}

Push-Location -LiteralPath $workingDirectory
try {
    $output = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Install-UptimeReboot.ps1 -ThresholdMinutes 60 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

"User: $([Security.Principal.WindowsIdentity]::GetCurrent().Name) | Folder: $workingDirectory | Exit code: $exitCode | LanguageMode: $($ExecutionContext.SessionState.LanguageMode)"
'ExecutionPolicy: ' + ((Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ', ')
'Output/errors: ' + (($output | Out-String).Trim())
