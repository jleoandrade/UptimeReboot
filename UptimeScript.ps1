$app = Get-CMApplication -Name '*Uptime*' | Select-Object -First 1
$dt = Get-CMDeploymentType -ApplicationName $app.LocalizedDisplayName | Where-Object LocalizedDisplayName -eq 'Lab - Uptime Maximum 1h'
"Application: $($app.LocalizedDisplayName) | App revision: $($app.CIVersion) | DT revision: $($dt.CIVersion)"
$installer = ([xml]$dt.SDMPackageXML).AppMgmtDigest.DeploymentType.Installer
"Install command: $($installer.CustomData.InstallCommandLine)"
$installer.CustomData.ExitCodes.ExitCode | Select-Object Code, Class | Format-Table -AutoSize
