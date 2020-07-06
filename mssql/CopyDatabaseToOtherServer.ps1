param(
    $SourceServer="STGHSQLDKHOS005",
    $SourceInstance="DEFAULT",
    $SourcePath="R:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup",
    $SourceUnc=("\\{0}\{1}" -f $SourceServer, $SourcePath.Replace(":", "$")),
    $TargetServer="STGHSQLDKHOS105",
    $TargetInstance="DEFAULT",
    $TargetPath="R:\",
    $DatabasePrefix="", # eg. tyg-
    $DatabaseSuffix="", # eg. (master|core|web)
    $SqlCmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe"
)

$ErrorActionPreference = "STOP"

If (Get-Module SQLSERVER -ListAvailable) {
    Import-Module SQLSERVER
} else {
    Install-Module SQLSERVER 
}

Set-Location SQLSERVER:\SQL\$SourceServer\$SourceInstance
$databases = Get-SqlDatabase | Select-Object -ExpandProperty Name `
                | Where-Object { $_ -imatch "${DatabasePrefix}.+" -and $_ -imatch ".+${DatabaseSuffix}" }

# Backup
$databases | ForEach-Object {
    $databaseName = $_
    $bakFile = "${databaseName}.bak"
    $file = "${SourceUnc}\${bakFile}"
    Write-Host "Backup ${databaseName} to ${file}"
    Backup-SqlDatabase -Database $databaseName -BackupFile $file -CopyOnly
}

Set-Location SQLSERVER:\SQL\$TargetServer\$TargetInstance -ErrorAction Break
$databases | ForEach-Object {
    $databaseName = $_
    $bakFile = "${databaseName}.bak"
    $file = "${SourceUnc}\${bakFile}"

    # Copy
    Copy-Item -Path $file -Destination $TargetFolder -Verbose

    # Restore
    $file = Join-Path $TargetFolder $bakFile
    Write-Host "Removing old database"
    Invoke-Sqlcmd -Query "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'${databaseName}'"
    Invoke-Sqlcmd -Query "ALTER DATABASE [${databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
    Invoke-Sqlcmd -Query "DROP DATABASE IF EXISTS [${databaseName}]"

    Restore-SqlDatabase -Database $databaseName -BackupFile $file -AutoRelocate
}
