param(
    $DbPrefix = "site-",
    $SitecorePrefix = "sc_",
    $PackagePath = $PWD,
    $PackageFilter = "*Core.dacpac",
    $SqlServer = ".",
    $SqlCmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe",
    $SqlPackage = "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\sqlpackage.exe"
)

$ErrorActionPreference = "STOP"

$files = Get-ChildItem -Path $PackagePath -Filter $PackageFilter
$files | ForEach-Object {
    $dacPath = $_.FullName
    $dbName = ("{0}{1}" -f $Prefix, $_.BaseName.Replace("Sitecore.", $SitecorePrefix))
    Write-Host "Deploy $dacPath to $dbName"

    & $SqlPackage /Action:Publish /SourceFile:$dacPath /TargetServerName:$SqlServer /TargetDatabaseName:$dbName
}
