$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "" #Dynamics user name of ExFlow Web administrators. Use comma to separate. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "https://axtestdynamics365aos.cloudax.dynamics.com" #URL to AX
$RepoURL                   = "https://github.com/signupsoftware/exflowwebd365o/blob/master/v2/" #URL to GitHub
$Prefix                    = "" #Optional prefix (short using alphanumeric characters). Name will be exflow[$prefix][xxxxxxxxxxx].
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$PackageVersion            = "latest" #Optional version to install.  Leave blank for default behavior.
$MachineSize               = "F1" #App Service machine (AKA Service Plan) size F1=Free (default), D1=Shared, B1 to B3= Basic, S1 to S3 = Standard, P1 to P3 = Premium  (see also https://azure.microsoft.com/en-us/pricing/details/app-service/)
$TenantGuid                = "" #Optional tenant id when you have multiple tenants (advanced). 
$WebAppSubscriptionGuid    = "" #Optional Subscription for the web app (advanced).


$Webclient                       = New-Object System.Net.Webclient
$Webclient.UseDefaultCredentials = $true
$Webclient.Proxy.Credentials     = $Webclient.Credentials
$Webclient.Encoding              = [System.Text.Encoding]::UTF8
$Webclient.CachePolicy           = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)

$scriptPath = ($Webclient.DownloadString("$($RepoURL)App-RegistrationDeployment.ps1"))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$RepoURL,$ExFlowUserSecret,$Prefix,$PackageVersion,$MachineSize,$TenantGuid,$WebAppSubscriptionGuid

