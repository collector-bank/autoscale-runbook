<#
.SYNOPSIS
    Vertically autoscale SQL and ASP.

.PARAMETER resourceGroupName
    Name of the resource group to which the database server is
    assigned.

.PARAMETER scalingSchedule
    Database Scaling Schedule. It is possible to enter multiple
    comma separated schedules: [{},{}]
    Weekdays start at 0 (sunday) and end at 6 (saturday).

.PARAMETER serverName
    Azure SQL Database server name.

.PARAMETER databaseName
    Azure SQL Database name (case sensitive).

.PARAMETER defaultSqlSku
    Default Azure SQL Database Sku.
    Available values: S0, S1, S2, S4, S5, S6, S7, S9, S12, P1, P2, P4, P6, P11, P15.

.PARAMETER scaledSqlSku
    Scaled Azure SQL Database Sku.
    Available values: S0, S1, S2, S4, S5, S6, S7, S9, S12, P1, P2, P4, P6, P11, P15.
    
.PARAMETER appServicePlanName
    Name of the App Service Plan

.PARAMETER defaultAspTier
    Default Azure App Service Plan Tier.
    Available values: Free, Shared, Basic, Standard, Premium, PremiumV2, PremiumV3, Isolated, IsolatedV2.

.PARAMETER defaultAspWorkers
    Default Numbers of instances of the App Service Plan.

.PARAMETER scaledAspTier
    Scaled Azure SQL Database Tier.
    Available values: Free, Shared, Basic, Standard, Premium, PremiumV2, PremiumV3, Isolated, IsolatedV2.

.PARAMETER scaledAspWorkers
    Scaled Numbers of instances of the App Service Plan.

.EXAMPLE
    -resourceGroupName myResourceGroup
    -scalingSchedule [{WeekDays:[1,2,3,4,5], StartTime:"06:59:59", StopTime:"17:59:59"}]

    -serverName mySqlServer
    -databaseName myDatabase
    -defaultSqlSku S0
    -scaledSqlSku S1

    -appServicePlanName myAppServicePlan
    -defaultAspTier Standard
    -defaultAspWorkers 1
    -scaledAspTier PremiumV2
    -scaledAspWorkers 3
#>

param(
    [parameter(Mandatory = $true)]
    [string] $resourceGroupName, 

    [parameter(Mandatory = $true)]
    [string] $scalingSchedule,

    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $serverName,

    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $databaseName,

    [ValidateSet('', 'S0', 'S1', 'S2', 'S4', 'S5', 'S6', 'S7', 'S9', 'S12', 'P1' , 'P2' , 'P4' , 'P6' , 'P11' , 'P15')]
    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $defaultSqlSku,

    [ValidateSet('', 'S0', 'S1', 'S2', 'S4', 'S5', 'S6', 'S7', 'S9', 'S12', 'P1' , 'P2' , 'P4' , 'P6' , 'P11' , 'P15')]
    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $scaledSqlSku,
    
    [parameter(Mandatory = $false)]
    [string] $appServicePlanName,

    [ValidateSet('', 'Free', 'Shared', 'Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3', 'Isolated', 'IsolatedV2')]
    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $defaultAspTier,

    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $defaultAspWorkers,

    [ValidateSet('', 'Free', 'Shared', 'Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3', 'Isolated', 'IsolatedV2')]
    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $scaledAspTier,

    [parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string] $scaledAspWorkers
)

filter timestamp { "[$(Get-Date -Format G)]: $_" }

Write-Output "Script started." | timestamp

if ([string]::IsNullOrEmpty($serverName) -or
    [string]::IsNullOrEmpty($databaseName) -or
    [string]::IsNullOrEmpty($defaultSqlSku) -or
    [string]::IsNullOrEmpty($scaledSqlSku)) {
    Write-Output "Database scaling is disabled" | timestamp
    $shouldScaleSql = $false
}
else {
    Write-Output "Database scaling is enabled" | timestamp
    $shouldScaleSql = $true
}

if ([string]::IsNullOrEmpty($appServicePlanName) -or
    [string]::IsNullOrEmpty($defaultAspTier) -or
    [string]::IsNullOrEmpty($defaultAspWorkers) -or
    [string]::IsNullOrEmpty($scaledAspTier) -or
    [string]::IsNullOrEmpty($scaledAspWorkers)) {
    Write-Output "App service plan scaling is disabled" | timestamp
    $shouldScaleAsp = $false
}
else {
    Write-Output "App service plan scaling is enabled" | timestamp
    $shouldScaleAsp = $true
}

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

#Authenticate with MSI
Write-Output "Connecting to azure via  Connect-AzAccount -Identity" | timestamp
Connect-AzAccount -Identity

$initialSql = new-Object PsObject
$initialAsp = new-Object PsObject

if ($shouldScaleSql) {
    $initialSql = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName 

    $initialSqlStatus = $initialSql.Status[0]
    $initialSqlSku = $initialSql.CurrentServiceObjectiveName[1]
    
    Write-Output "Initial database status: $($initialSqlStatus), sku: $($initialSqlSku)" | timestamp
}
if ($shouldScaleAsp) {
    $initialAsp = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName

    $initialAspStatus = $initialAsp.Status
    $initialAspWorkers = $initialAsp.Sku.Capacity
    $initialAspTier = $initialAsp.Sku.Tier

    Write-Output "Initial app service plan status: $($initialAspStatus), workers: $($initialAspWorkers), tier: $($initialAspTier)" | timestamp
}

function SetScaledDatabase {
    Write-Output "Check if database is scaled already." | timestamp
    if ($initialSqlSku -ne $scaledSqlSku) {
        Write-Output "Database is not scaled already." | timestamp
        Write-Output "Scaling database to sku $scaledSqlSku initiated..." | timestamp
        try {
            Set-AzSqlDatabase -ResourceGroupName $resourceGroupName -DatabaseName $databaseName -ServerName $serverName -RequestedServiceObjectiveName $scaledSqlSku
        }
        catch {
            $message = $_
            Write-Warning "Error scaling Sql: $message" | timestamp
        }
    }
    else {
        Write-Output "Database sku is scaled already. Exiting" | timestamp
    }
}

function SetScaledAppServicePlan {
    Write-Output "Check if current app service plan is scaled already" | timestamp
    if ($initialAspTier -ne $scaledAspTier -or $initialAspWorkers -ne $scaledAspWorkers) {
        Write-Output "App service plan is not scaled already." | timestamp
        Write-Output "Scaling app service plan to tier $scaledAspTier with $scaledAspWorkers workers initiated..." | timestamp
        try {
            Set-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -Tier $scaledAspTier -NumberofWorkers $scaledAspWorkers
        }
        catch {
            $message = $_
            Write-Warning "Error scaling app service plan: $message" | timestamp
        }
    }
    else {
        Write-Output "App service plan is scaled already. Exiting." | timestamp
    }
}

function SetDefaultDatabase {
    Write-Output "Check if current database is default already." | timestamp
    if ($initialSqlSku -ne $defaultSqlSku) {
        Write-Output "Database is not in default scaling." | timestamp
        Write-Output "Scaling database to default sku $defaultSqlSku initiated." | timestamp
        try {
            Set-AzSqlDatabase -ResourceGroupName $resourceGroupName -DatabaseName $databaseName -ServerName $serverName -RequestedServiceObjectiveName $defaultSqlSku 
        }
        catch {
            $message = $_
            Write-Warning "Error scaling Sql $message" | timestamp
        }
    }
    else {
        Write-Output "Database sku is in default scaling already. Exiting." | timestamp
    }
}

function SetDefaultAppServicePlan {
    Write-Output "Check if current app service plan is in default scaling already." | timestamp
    if ($initialAspTier -ne $defaultAspTier -or $initialAspWorkers -ne $defaultAspWorkers) {   
        Write-Output "App service plan not in default scaling already." | timestamp
        Write-Output "Scaling to default tier $defaultAspTier with $defaultAspWorkers workers initiated" | timestamp
        try {
            Set-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -Tier $defaultAspTier -NumberofWorkers $defaultAspWorkers
        }
        catch {
            $message = $_
            Write-Warning "Error scaling App service plan: $message" | timestamp
        }
    }
    else {
        Write-Output "App service plan is in default scaling already. Exiting." | timestamp
    }
}

#Get current date and convert to timezone
$now = Get-Date
$timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("W. Europe Standard Time")
$startTime = [System.TimeZoneInfo]::ConvertTime($now, $timeZone)
Write-Output "Time: $($startTime)." | timestamp

#Get day of week
$currentDayOfWeek = [Int]($startTime).DayOfWeek
Write-Output "Current day of week: $currentDayOfWeek." | timestamp

#Get the scaling schedule for the current day of week
$scalingObject = $scalingSchedule | ConvertFrom-Json | Where-Object { $_.WeekDays -contains $currentDayOfWeek } `
| Select-Object `
@{Name = "StartTime"; Expression = { [datetime]::ParseExact(($startTime.ToString("yyyy:MM:dd") + ":" + $_.StartTime), "yyyy:MM:dd:HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) } }, `
@{Name = "StopTime"; Expression = { [datetime]::ParseExact(($startTime.ToString("yyyy:MM:dd") + ":" + $_.StopTime), "yyyy:MM:dd:HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) } }

if ($scalingObject -ne $null) {
    $matchingObject = $scalingObject | Where-Object { ($startTime -ge $_.StartTime) -and ($startTime -lt $_.StopTime) } | Select-Object -First 1
    if ($matchingObject -ne $null) {
        Write-Output "In scaled time window, setting scaled configuration." | timestamp
        if ($shouldScaleSql) {
            SetScaledDatabase
        }
        if ($shouldScaleAsp) {
            SetScaledAppServicePlan
        }
    }
    else {
        Write-Output "Not in scaled time window, setting default configuration." | timestamp
        if ($shouldScaleSql) {
            SetDefaultDatabase
        }
        if ($shouldScaleAsp) {
            SetDefaultAppServicePlan
        }
    }
}
else {
    Write-Output "No schedule found. Exiting" | timestamp
}

if ($shouldScaleSql) {
    $finalSql = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName

    $finalSqlStatus = $finalSql.Status[0]
    $finalSqlSku = $finalSql.CurrentServiceObjectiveName[1]

    Write-Output "Final database status: $($finalSqlStatus), sku: $($finalSqlSku)" | timestamp
}

if ($shouldScaleAsp) {
    $finalAsp = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName

    $finalAspStatus = $finalAsp.Status
    $finalAspWorkers = $finalAsp.Sku.Capacity
    $finalAspTier = $finalAsp.Sku.Tier

    Write-Output "Final app service plan status: $($finalAspStatus), workers: $($finalAspWorkers), tier: $($finalAspTier)" | timestamp
}

Write-Output "Script finished." | timestamp
