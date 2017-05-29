# ExFlow web for D365O
ExFlow web for *Dynamics 365 for Operations* (D365O) runs in Azure as a fully scalable *Azure App Service*. ExFlow web is deployed into the tenant’s Azure environment as a Resource Group that contains a Web Site and a Storage account. The website is further connected to the Azure AD and D365O thru a so called App Registration and communicates with D365O using the same security technology that D365O uses namely Azure AD and OAuth 2.0.

## Installation and updates
ExFlow web is installed by running the following PowerShell script ([Example.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/Example.ps1)) in *Powershell ISE*.


```powershell
$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "JOHANB,JERRY" #AX user name (UPPERCASE) of ExFlow web administrators. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "axtestdynamics365aos.cloudax.dynamics.com" #URL such as axtestdynamics365aos.cloudax.dynamics.com
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #Optional prefix (short using alphanumeric characters). Leave blank for default behavior.
$PackageVersion            = "" #Optional version to install.  Leave blank for default behavior.

$scriptPath = ((New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/App-RegistrationDeployment.ps1'))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$ExFlowUserSecret,$Prefix,$PackageVersion 
```

The script downloads the latest ExFlow web release and installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the D365O API (web services). **Note that to apply product updates you just run the script again.**

### Instructions:
1. Open PowerShell ISE
2. Change parameters $location, $Security_Admins, $DynamicsAXApiId, $ExFlowUserSecret  (see inline comments)
3. Press Play
4. When prompted sign in using an Azure admin account
5. Wait until done
6. Sign in to the app and grant permissions 

*Error handling:*

If the text in the command window turns red something went wrong 
1.  Press the Stop button
2.  Verify that you are using an account with enough rights to create an App registration. Note that you can't use an account with 2-factor authentication with PowerShell. Also, make sure that the account is part of the subscription admin group.
3.  Make sure that you have AzureRM installed. Open PowerShell ISE with **Run as administrator** and run the following command:
```powershell
Install-Module -Name AzureRM
```
4. If above step still fails you will need to upgrade to a later version of PowerShell. Go to https://msdn.microsoft.com/en-us/powershell/wmf/5.0/requirements.


## Release notes
Compared with version 3 the following features have been removed.
* Support for all IE versions <11 are dropped. 
* IE11 not supported in so-called **Compatibility mode**. 
* Coding favorites have been deprecated and will be replaced by enhanced line templates.
* IE11 on Windows Server using default security configuration where localStorage is disabled is not supported. 

The following features are currently under development.
* Boolean coding columns not supported.
* Paging/"scroll for more" in lookups (account, items, ..) are under development. 
* Line templates

### Release 16 
2017-05-30, AX2012, D365AX

**News**
* Improves keyboard navigation using adding ESC to escape line editing.
* Improves the Forward feature adding the possibility to disable the Previous option. The OK button is also disabled until approver and comment have been specified.
* Improves filtering for adding approvers (Add Approver & Forward To)
* Improves display of the Amount column in the inbox.
* Adds possibility for an administrator to download the latest logfile (experimental).
* Adds possibility to turn on extended logging in admin settings (experimental).
* Adds admin option to manually clean temporary files and folders (experimental). 
* Bug fixes.

### Release 15 
Applies to D365O (not released), AX2012 (20170428)

**News**
* Fixes a critical bug that sometimes stopped final approval
* Improved language files and translation support - custom labeling.
* Automatic theme (color) change based on a number of due documents (experimental).
* Adds full support for keyboard shortcuts.
* Adds possibility to change line type.
* Improves splitting with a possibility to quickly change the original line amount.
* (AX2012) Support Azure AD. 

### Release 14 (2017-04-04)
Applies to D365O

**News**

* ARM template deployment with form ISE PowerShell
* Bug fixes

### Release 13 (2017-03-29)
Applies to D365O (prerelease), AX2012

**News**

* Adds document drafting and autosave. Changes to lines and coding are automatically stored by the system.
* Handles browser back navigation
* Improves display of coding columns
* Improves mobile UI/UX
* Includes a read up (help tutorial) with animated images.
* Bug fixes

