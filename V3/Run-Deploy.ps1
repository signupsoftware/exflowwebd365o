$Location                  = "westeurope" #Azure location such as northeurope,westeurope...
$Security_Admins           = "ADMIN" #Dynamics user name of ExFlow Web administrators. Use comma to separate. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "https://axtestdynamics365aos.cloudax.dynamics.com" #URL to AX
$RepoURL                   = "https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/V3/" #URL to GitHub or the download location for example c:\folder\. 
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #Optional prefix but recommended (short using alphanumeric characters). Name will be exflow[$prefix][xxxxxxxxxxx].
$PackageVersion            = "" #Optional version to install.  Leave blank for default behavior.
$MachineSize               = "" #App Service machine (AKA Service Plan) size F1=Free, D1=Shared, B1 (default) to B3= Basic, S1 to S3 = Standard, P1 to P3 = Premium  (see also https://azure.microsoft.com/en-us/pricing/details/app-service/)
$TenantGuid                = "" #Optional tenant id when you have multiple tenants (advanced). 
$WebAppSubscriptionGuid    = "" #Optional Subscription for the web app (advanced).
$UseApiName                = "" #Optional. Set to "true" use the same name as the left part of $DynamicsAXApiId e.g. axtestdynamics365aos. 
$ResourceGroup             = "" #Optional. Set a custom ResourceGroup name.
$AppServicePlan            = "" #Optional. Set a custom ASP name.
$AppControlMergeFile       = "App.AX.WS.xml?{ax365api1}=true;{UseDebugLog}=false;{Lines.RemoveOrginal}=true;{Lines.ChangeType}=true;{ForwardTo}=true;{ForwardTo.NoPrevious}=true;{Lang.All}=true;{Lines.UseLineTemplates}=true;{Lines.UseAsyncValidation}=true;{Labs.Vue.InAppSiteConfiguration}=true;" #Enables or disabled features in the web, leave as is for a standard deployment.


$Webclient                       = New-Object System.Net.Webclient
$Webclient.UseDefaultCredentials = $true
$Webclient.Proxy.Credentials     = $Webclient.Credentials
$Webclient.Encoding              = [System.Text.Encoding]::UTF8
$Webclient.CachePolicy           = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)

$scriptPath = ($Webclient.DownloadString("$($RepoURL)App-RegistrationDeployment.ps1"))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$RepoURL,$ExFlowUserSecret,$Prefix,$PackageVersion,$MachineSize,$TenantGuid,$WebAppSubscriptionGuid,$UseApiName,$ResourceGroup,$AppServicePlan,$AppControlMergeFile
