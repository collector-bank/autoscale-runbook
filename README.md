# autoscale-runbook
### Vertically autoscale SQL and/or ASP.
```
Example
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
```
Refer from terraform-runbook-setup, using latest master:
```
  publish_content_link {
    uri = "https://raw.githubusercontent.com/collector-bank/autoscale-runbook/712f0c5f919f8888233fe0c26d0e0751ac866591/autoscale.ps1"
  }
```
or using certain commit:
```
  publish_content_link {
    uri = "https://raw.githubusercontent.com/collector-bank/autoscale-runbook/main/autoscale.ps1"
  }
```

Assumes Automation-account has access to sql-server and/or app service plan.
