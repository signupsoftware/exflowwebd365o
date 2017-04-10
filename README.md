# ExFlow web for D365O
ExFlow web for *Dynamics 365 for Operations* (D365O) runs in Azure as a fully scalable *Azure App Service*. ExFlow web is deployed into the tenant’s Azure environment as a Resource Group that contains a Web Site and a Storage account. The website is further connected to the Azure AD and D365O thru a so called App Registration and communicates with D365O using the same security technology that D365O uses namely Azure AD and OAuth 2.0.

## Installation and updates
ExFlow web is installed by running the following PowerShell script ([Example.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/Example.ps1)) in *Powershell ISE*.


```powershell
$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "JOHANB,JERRY" #AX user name of web site administrators. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "axtestdynamics365aos" #left part of the AX URL such as axtestdynamics365aos for https://axtestdynamics365aos.cloudax.dynamics.com
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com

$scriptPath = ((New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/App-RegistrationDeployment.ps1'))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$ExFlowUserSecret 
```

The script downloads the latest ExFlow web release and installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the D365O API (web services). **Note that to apply product updates you just run the script again.**

### Instructions:
1. Open PowerShell ISE
2. Install/Verify AzureRM (see Error handling)
3. Change parameters $location, $Security_Admins, $DynamicsAXApiId, $ExFlowUserSecret  (see inline comments)
4. Press Play
5. When prompted sign in using an Azure admin account
6. Wait until done
7. Sign in to the app and grant permissions 

Error handling:
If the text in the command window turns red something went wrong 
1.  Press the Stop button
2.  Verify that you are using an account with enough rights to create an App registration
3.  Make sure that you have AzureRM installed using:
```powershell
Install-Module AzureRm
```


## Release notes
Compared with version 3 the following features have been removed.
* Support for all IE versions <11 are dropped. 
* IE11 not supported in so-called **Compatibility mode**. 
* Coding favorites have been deprecated and will be replaced by enhanced line templates.
* IE11 on Windows Server using default security configuration where localStorage is disabled is not supported. 

The following features are currently under development.
* Ax2012 change line type.
* Keyboard navigation not fully implemented.
* Boolean coding columns not supported.
* Paging/"scroll for more" in lookups (account, items, ..) are under development. 
* Azure AD for AX2012 is under development.
* Line templates


### Release 14 (2017-04-04)
Applies to D365O
###News
* ARM template deployment with form ISE PowerShell
* Bug fixes

##Release 13 (2017-03-29)
Applies to D365O (prerelease), AX2012
###News
* Adds document drafting and autosave. Changes to lines and coding are automatically stored by the system.
* Handles browser back navigation
* Improves display of coding columns
* Improves mobile UI/UX
* Includes a read up (help tutorial) with animated images.
* Bug fixes

