# Version 1
ExFlow web for *Dynamics 365 for Operations* (D365O) runs in Azure as a fully scalable *Azure App Service*. ExFlow web is deployed into the tenant’s Azure environment as a Resource Group that contains a Web Site and a Storage account. The website is further connected to the Azure AD and D365O thru a so called App Registration and communicates with D365O using the same security technology that D365O uses namely Azure AD and OAuth 2.0.


## Installation and updates
ExFlow web is installed by running the following PowerShell script ([Example.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/Example.ps1)) in *Powershell ISE*.


```powershell
$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "JOHANB,JERRY" #AX user name (UPPERCASE) of ExFlow web administrators. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "axtestdynamics365aos.cloudax.dynamics.com" #URL host such as axtestdynamics365aos.cloudax.dynamics.com
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #Optional prefix (short using alphanumeric characters). Leave blank for default behavior.
$PackageVersion            = "" #Optional version to install.  Leave blank for default behavior.
$TenantGuid                = "" #Optional tenant id when you have multiple tenants (advanced).   
$SubscriptionGuid          = "" #Optional Subscription for the web app (advanced). Use if you have two subscriptions, one holding tenant (AD) and another for apps. You will be prompted twice for credentials, (1) use AD admin account, (2) the subscription co-admin for the second subscription.       

$scriptPath = ((New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/V1/App-RegistrationDeployment.ps1'))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$ExFlowUserSecret,$Prefix,$PackageVersion,$TenantGuid,$SubscriptionGuid 

```

The script downloads the latest ExFlow web release and installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the D365O API (web services). **Note that to apply product updates you just run the script again.**

### Instructions:
1. Open PowerShell ISE
2. Change parameters $location, $Security_Admins, $DynamicsAXApiId, $ExFlowUserSecret  (see inline comments)
3. Press Play
4. When prompted sign in using an Azure admin account
5. Wait until done
6. Sign in to the app and grant permissions 

If the text in the command window turns red or the script aborts something went wrong, see bellow section on errors.

# Error handling

If the text in the command window turns red or the script aborts something went wrong. 
1.  Press the Stop button
2.  Verify that you are using an account with enough rights to create an App registration. Note that you can't use an account with 2-factor authentication with PowerShell. Also, make sure that the account is part of the subscription admin group.
3.  Make sure that you have AzureRM installed. Open PowerShell ISE with **Run as administrator** and run the following command:
```powershell
Install-Module -Name AzureRM
```
4. If above step still fails you may have to need to upgrade to a later version of PowerShell. Go to https://msdn.microsoft.com/en-us/powershell/wmf/5.0/requirements.

## Remove
In the Azure Portal:
1. Sign in and locate 'Resource Groups' in the menu. Find the resource group to remove (start with 'exflow...').
2. Open, press 'Delete' and follow instructions.
3. Locate 'App Registrations' in the menu. Find app (they always start with exflow), press 'Delete' and follow instructions.

