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
    $SqlCmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe",

    [Switch]$SkipBackup,
    [Switch]$SkipCopy,
    [Switch]$SkipRemoveOld,
    [Switch]$SkipRestore
)

$ErrorActionPreference = "STOP"

If (Get-Module SQLSERVER -ListAvailable) {
    Import-Module SQLSERVER
} else {
    Install-Module SQLSERVER 
}

    If(-not (Test-Path $TargetPath)) {
        New-Item $TargetPath -ItemType Directory | Out-Null
    }

try {
    Push-Location SQLSERVER:\SQL\$SourceServer\$SourceInstance
    $databases = Get-SqlDatabase | Select-Object -ExpandProperty Name `
                    | Where-Object { $_ -imatch "${DatabasePrefix}.+" -and $_ -imatch ".+${DatabaseSuffix}" }

    # Backup
    If(-not $SkipBackup) {
        $databases | ForEach-Object {
            $databaseName = $_
            $bakFile = "${databaseName}.bak"
            $file = "${SourceUnc}\${bakFile}"
            Write-Host "Backup ${databaseName} to ${file}"
            Backup-SqlDatabase -Database $databaseName -BackupFile $file -CopyOnly
        }
    }
} finally {
    Pop-Location
}



try {
    Push-Location SQLSERVER:\SQL\$TargetServer\$TargetInstance -ErrorAction Stop
    $databases | ForEach-Object {
        $databaseName = $_
        $bakFile = "${databaseName}.bak"

        # Copy
        if(-not $SkipCopy) {
            $ErrorActionPreference = "Continue"
            & robocopy ${SourceUnc} $TargetPath $bakFile /NFL /NDL /NC /NS /NP /NJH /NJS
            $ErrorActionPreference = "Stop"
        }

        $file = Join-Path $TargetPath $bakFile -Resolve

        # Restore
        If(-not $SkipRemoveOld) {
            $file = Join-Path $TargetFolder $bakFile
            Write-Host "Removing old $databaseName"
            $ErrorActionPreference = "SilentlyContinue"
            Invoke-Sqlcmd -Query "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'${databaseName}'"
            Invoke-Sqlcmd -Query "ALTER DATABASE [${databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
            Invoke-Sqlcmd -Query "DROP DATABASE IF EXISTS [${databaseName}]"
            $ErrorActionPreference = "Stop"
        }

        If(-not $SkipRestore) {
            Write-Host "Restore $databaseName"
            Restore-SqlDatabase -Database $databaseName -BackupFile $file -AutoRelocate
        }
    }
} finally {
    Pop-Location
}
