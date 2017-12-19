# PowerShell script ExFlow Web for D365O version 2

News in this version (V2) of the script: 
* Adds extended logging to a separate file.
* Adds support for multifactor authentication
* Adds support to install into a subscription that is connected to another directory/Azure AD. 
* Removes the need to store app secret/credentials (used in updates) locally. 
* Adds options ($UseApiName="true") to use the left part of the Dynamics URL as the name. For example, if the Dynamics URL is https://axtestdynamics365aos.cloudax.dynamics.com and $Prefix="exflow-" the URL becomes exflow-**axtestdynamics365aos**.azurewebsites.net.

## Installation and updates
ExFlow web is installed by running the following PowerShell script. See also ([Run-Deploy.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/v2/Run-Deploy.ps1)) in *Powershell ISE*. 


```powershell
$Location                  = "westeurope" #Azure location such as northeurope,westeurope...
$Security_Admins           = "ADMIN" #Dynamics user name of ExFlow Web administrators. Use comma to separate. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "https://axtestdynamics365aos.cloudax.dynamics.com" #URL to AX
$RepoURL                   = "https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/V2/" #URL to GitHub or the download location for example c:\folder\. 
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #Optional prefix but recommended (short using alphanumeric characters). Name will be exflow[$prefix][xxxxxxxxxxx].
$PackageVersion            = "" #Optional version to install.  Leave blank for default behavior.
$MachineSize               = "" #App Service machine (AKA Service Plan) size F1=Free, D1=Shared, B1 (default) to B3= Basic, S1 to S3 = Standard, P1 to P3 = Premium  (see also https://azure.microsoft.com/en-us/pricing/details/app-service/)
$TenantGuid                = "" #Optional tenant id when you have multiple tenants (advanced). 
$WebAppSubscriptionGuid    = "" #Optional Subscription for the web app (advanced).
$UseApiName                = "" #Optional. Set to "true" use the same name as the left part of $DynamicsAXApiId e.g. axtestdynamics365aos. 



$Webclient                       = New-Object System.Net.Webclient
$Webclient.UseDefaultCredentials = $true
$Webclient.Proxy.Credentials     = $Webclient.Credentials
$Webclient.Encoding              = [System.Text.Encoding]::UTF8
$Webclient.CachePolicy           = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)

$scriptPath = ($Webclient.DownloadString("$($RepoURL)App-RegistrationDeployment.ps1"))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$RepoURL,$ExFlowUserSecret,$Prefix,$PackageVersion,$MachineSize,$TenantGuid,$WebAppSubscriptionGuid,$UseApiName



```

The script downloads the latest ExFlow web release and installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the D365O API (web services). **Note that to apply product updates you just run the script again.**

## AzureRM Module
To successfully run the script you will need an updated PowerShell version. The script also depends on the AzureRM module, 
written by Microsoft. PowerShell and the AzureRM update frequently and updates are rarely (never) backwards compatible. Also, all versions stack up making the environment a bit unstable/unpredictable. One way of avoiding this is to uninstall modules. 
```powershell
Uninstall-Module -Name AzureRM -AllVersions
```
and then reinstall the module again
```powershell
Install-Module -Name AzureRM
```
Finally close and reopen the PowerShell ISE console.

### Instructions:
1. Open PowerShell ISE
2. Change parameters (see inline comments)
3. Press Play
4. When prompted sign in using an Azure Subscription Contributor (or higher) account
5. If you are prompted for credentials again use an Azure AD user i.e. ...@company.com
6. Respond to additional prompts and wait until done
7. Open URL and grant the app permissions 

If the text in the command window turns red or the script aborts something went wrong, see below section on errors.
