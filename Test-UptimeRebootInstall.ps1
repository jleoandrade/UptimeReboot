<#
.SYNOPSIS
    Diagnostic for the "Uptime Reboot" application: reproduces the exact install command line that SCCM
    executed and shows the real error message that SCCM only reports as "exit code 1".

.DESCRIPTION
    Safe to run: Install-UptimeReboot.ps1 never restarts the computer, it only returns an exit code.
    The install script is executed ONLY if the file in the cache is the expected version.

    Run on the affected computer, in an elevated Windows PowerShell 5.1 session (not PowerShell 7),
    or as SYSTEM through Software Library > Scripts (Run Script) to reproduce the SCCM context exactly.
#>

$ErrorActionPreference = 'Continue'
$appEnforceLog = 'C:\Windows\CCM\Logs\AppEnforce.log'
$solutionLog = 'C:\ProgramData\Corporate\UptimeReboot\UptimeReboot.log'
$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

"=== Context: $([Security.Principal.WindowsIdentity]::GetCurrent().Name), PowerShell $($PSVersionTable.PSVersion), LanguageMode $($ExecutionContext.SessionState.LanguageMode)"

"=== Execution policy (MachinePolicy/UserPolicy come from GPO and override -ExecutionPolicy Bypass)"
Get-ExecutionPolicy -List | Out-String

# 1. Working directory and command line of the last SCCM run of this application
$workingDirectory = Select-String -Path $appEnforceLog -Pattern 'Working directory (.+?)\]LOG\]' |
    Select-Object -Last 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
$commandLine = Select-String -Path $appEnforceLog -Pattern 'Executing Command line: (.+?) with user context' |
    Select-Object -Last 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }

"=== Last SCCM working directory: $workingDirectory"
"=== Last SCCM command line: $commandLine"
if ($commandLine) {
    $commandLine.ToCharArray() | Where-Object { [int]$_ -gt 127 } |
        ForEach-Object { 'WARNING: non-ASCII character in command line: U+{0:X4}' -f [int]$_ }
}
if (-not $workingDirectory -or -not (Test-Path -LiteralPath $workingDirectory)) {
    'STOP: working directory not found in AppEnforce.log or no longer present.'
    return
}

# 2. Content of the cache folder
"=== Files in $workingDirectory"
Get-ChildItem -LiteralPath $workingDirectory -Force | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String

$script = Join-Path $workingDirectory 'Install-UptimeReboot.ps1'
if (-not (Test-Path -LiteralPath $script)) {
    'STOP: Install-UptimeReboot.ps1 is not in the cache folder.'
    return
}

# 3. File checks: parse errors, version marker, non-ASCII bytes, Zone.Identifier
$tokens = $null; $parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors)
"=== Parse errors: $(@($parseErrors).Count)"
$parseErrors | ForEach-Object { '  Line {0}: {1}' -f $_.Extent.StartLineNumber, $_.Message }

$bytes = [IO.File]::ReadAllBytes($script)
"=== Size: $($bytes.Length) bytes, non-ASCII bytes: $(@($bytes | Where-Object { $_ -gt 127 }).Count)"
"=== Version marker found: $(Select-String -LiteralPath $script -Pattern 'ExitRebootRequired  = 17010' -Quiet)"
"=== Zone.Identifier (downloaded file mark): $([bool](Get-Item -LiteralPath $script -Stream Zone.Identifier -ErrorAction SilentlyContinue))"

if (@($parseErrors).Count -gt 0) { 'STOP: fix the file in the source folder and run Update Content.'; return }

# 4. Same command line as the deployment type, with the error stream captured
"=== Running the install exactly as SCCM does"
Push-Location -LiteralPath $workingDirectory
try {
    $output = & $powershellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\Install-UptimeReboot.ps1 -ThresholdMinutes 60 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
"=== Exit code: $exitCode"
"=== PowerShell output and errors:"
$output | Out-String

# 5. What the script logged, and what Windows logged around the SCCM run
"=== Last lines of UptimeReboot.log"
Get-Content -Path $solutionLog -Tail 5 -ErrorAction SilentlyContinue

$since = (Get-Date).AddHours(-2)
"=== PowerShell errors (event 4100) in the last 2 hours"
Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; Id = 4100; StartTime = $since } -ErrorAction SilentlyContinue |
    Select-Object -First 5 | ForEach-Object { "$($_.TimeCreated)  $(($_.Message -split "`r?`n" | Select-Object -First 3) -join ' | ')" }

"=== Defender detections and ASR blocks (1116/1117/1121/1122) in the last 2 hours"
Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Windows Defender/Operational'; Id = 1116, 1117, 1121, 1122; StartTime = $since } -ErrorAction SilentlyContinue |
    Select-Object -First 5 | ForEach-Object { "$($_.TimeCreated)  $(($_.Message -split "`r?`n" | Select-Object -First 4) -join ' | ')" }
