# ExFlow web for D365O
ExFlow web for *Dynamics 365 for Operations* (D365O) runs in Azure as a fully scalable *Azure App Service*. ExFlow web is deployed into the tenant’s Azure environment as a Resource Group that contains a Web Site and a Storage account. The website is further connected to the Azure AD and D365O thru a so-called App Registration and communicates with D365O using the same security technology that D365O uses namely Azure AD and OAuth 2.0.

## PowerShell deployment script - NEW VERSION
We have a new version of the script called [V2](https://github.com/signupsoftware/exflowwebd365o/tree/master/V2) that we recommend for new deployments. If you wish to continue using the original version of the script see [V1](https://github.com/signupsoftware/exflowwebd365o/tree/master/V1).

New in this version (V2) of the script: 
* Adds extended logging to a separate file.
* Adds support for multifactor authentication
* Adds support to install into a subscription that is connected to another directory/Azure AD. 
* Removes the need to store app secret/credentials (used in updates) locally. 
* Adds options ($UseApiName="true") to use the left part of the Dynamics URL as the name. For example, if the Dynamics URL is *axtestdynamics365aos*.cloudax.dynamics.com and $Prefix="exflow-" the URL becomes *exflow-axtestdynamics365aos*.azurewebsites.net.
* Script will now prompt for subscription id when multiple subscriptions is found.

## Installation and updates
ExFlow web is installed by running the following PowerShell script. See also ([Run-Deploy.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/v2/Run-Deploy.ps1)) in *Powershell ISE*. 


```powershell
$Location                  = "westeurope" #Azure location such as northeurope,westeurope...
$Security_Admins           = "ADMIN" #Dynamics user name of ExFlow Web administrators. Use comma to separate. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "https://axtestdynamics365aos.cloudax.dynamics.com" #URL to AX
$RepoURL                   = "https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/V2/" #URL to GitHub or the download location for example c:\folder\. 
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #(Optional) Name prefix (short using alphanumeric characters). Name will be exflow[$prefix][xxxxxxxxxxx]. If UseApiName is used then name will be [$prefix][dynamics_sub_domain].azurewebsites.net
$PackageVersion            = "" #(Optional) Version to install. Leave blank for default behavior.
$MachineSize               = "" #(Optional) App Service machine (AKA Service Plan) size F1=Free, D1=Shared, B1 (default) to B3= Basic, S1 to S3 = Standard, P1 to P3 = Premium  (see also https://azure.microsoft.com/en-us/pricing/details/app-service/)
$TenantGuid                = "" #(Optional) Tenant id when you have multiple tenants (advanced). 
$WebAppSubscriptionGuid    = "" #(Optional) Subscription id when you have multiple subscriptions for the web app (advanced).
$UseApiName                = "" #(Optional) Set to "true" use the same name as the left part of $DynamicsAXApiId e.g. axtestdynamics365aos. 



$Webclient                       = New-Object System.Net.Webclient
$Webclient.UseDefaultCredentials = $true
$Webclient.Proxy.Credentials     = $Webclient.Credentials
$Webclient.Encoding              = [System.Text.Encoding]::UTF8
$Webclient.CachePolicy           = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)

$scriptPath = ($Webclient.DownloadString("$($RepoURL)App-RegistrationDeployment.ps1"))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$RepoURL,$ExFlowUserSecret,$Prefix,$PackageVersion,$MachineSize,$TenantGuid,$WebAppSubscriptionGuid,$UseApiName



```

The script downloads the latest ExFlow web release and installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the D365O API (web services). **Note that to apply product updates you just run the script again.**

## AzureRM Modules
To successfully run the script you will need an updated PowerShell version. The script also depends on the AzureRM module, 
written by Microsoft. PowerShell and the AzureRM update frequently and updates are rarely (never) backward compatible. Also, all versions stack up making PowerShell a bit unpredictable. One way of avoiding this is to uninstall modules. 
```powershell
Uninstall-Module -Name AzureRM -AllVersions
```
and then reinstall the module again
```powershell
Install-Module -Name AzureRM
```
Finally, close and reopen the PowerShell ISE console.

## Instructions:
1. Open PowerShell ISE
2. Change parameters (see inline comments)
3. Press Play
4. When prompted sign in using an Azure Subscription Contributor (or higher) account
5. If you are prompted for credentials again use an Azure AD user i.e. ...@company.com
6. Respond to additional prompts and wait until done
7. Open URL and grant the app permissions 

If the text in the command window turns red or the script aborts something went wrong, see below section on errors.

We also recommend that you install [Microsoft Azure Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer) (MASE). 

MASE allows you to: 
* Export (and import) the "keyvalue" table as a CSV file.
* Get a shared access signature to the "diagnostics" with our log files.

Another tool from Microsoft is [AzCopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy) that allows you to backup content from storage from the command line. 

Example export table using AzCopy:

```cmd

AzCopy /Source:https://[STORAGE NAME].table.core.windows.net/keyvalues/ /manifest:keyvalue.manifest /Dest:C:\myfolder\ /SourceKey:[STORAGE KEY]

```



## Release notes
Compared with version 3 the following features have been removed.
* Support for all IE versions <11 is dropped. 
* IE11 not supported in so-called **Compatibility mode**. 
* Coding favorites have been deprecated and will be replaced by enhanced line templates.
* IE11 on Windows Server using default security configuration where localStorage is disabled is not supported. 

The following features are currently under development.
* Boolean coding columns not supported.
* Paging/"scroll for more" in lookups (account, items, ..) are under development. 
* Line templates

### Version 2018.4.1
2018-04-27

**News in this release**
* Adds support for automatically generated split and coding templates. 
   * The feature is in public preview*.
   * Older existing templates aren't overwritten but the feature doesn't include an import. 
* The sign-out button has been moved from search panel to avoid unintentional signouts.
* The number of documents in each folder (Inbox, Due, ...) is displayed next to each folder.
* Fixes an issue with the search panel where suggestion lists on textboxes could get stuck after a search.
* This release applies to Dynamics NAV, AX 2012 and 365fO.

\* PREVIEWS ARE PROVIDED "AS-IS," "WITH ALL FAULTS," AND "AS AVAILABLE," AND ARE EXCLUDED FROM THE SERVICE LEVEL AGREEMENTS AND LIMITED WARRANTY. 

### Release 2017.20.0.0
2017-12-06 for AX12, D365O, NAV

**News**
* Improves PDF image interaction
* Coding suggestion lists filters on partial value matches (AX12, D365O)
* New languages AU and NZ
* New versioning syntax 2017.Release no.Custom no.Patch no
* Search and some inbox folders will sort based on Document Date or user preference rather than Due date.
* Adds inbox/search sorting by column click
* Improves dashboard chart interaction
* Adds line comments highlighting
* Improves line and inbox paging and scrolling
* Other UI improvements
* Bug fixes


### Release 17
No. 4.17, 2017-08-30, AX2012, D365AX, NAV (pre)

**New**
* Adds UI improvements.
* Improves client-side performance.
* Improves performance when reloading settings from Dynamics.
* Fixes a critical issue with PDF-files for D365
* Changes how the primary button work (the green one). The primary button will change from Approve (i.e. approve all lines) to Save/Send when the user makes a line approval decision.
* Bug fixes
    * Attachments added in web wasn't saved  [AX2012] (4.17.0.2) 
    * Fixes an issue with line headers on IE and Edge (4.17.0.2)

### Release 16 
2017-05-30, AX2012, D365AX

**New**
* Improves keyboard navigation using adding ESC to escape line editing.
* Improves the Forward feature adding the possibility to disable the Previous option. The OK button is also disabled until approver and comment have been specified.
* Improves filtering for adding approvers (Add Approver & Forward To)
* Improves display of the Amount column in the inbox.
* Adds possibility for an administrator to download the latest log file (experimental).
* Adds possibility to turn on extended logging in admin settings (experimental).
* Adds admin option to manually clean temporary files and folders (experimental). 
* Bug fixes.

### Release 15 
Applies to D365O (not released), AX2012 (20170428)

**New**
* Fixes a critical bug that sometimes stopped final approval
* Improved language files and translation support - custom labeling.
* Automatic theme (color) change based on a number of due documents (experimental).
* Adds full support for keyboard shortcuts.
* Adds possibility to change line type.
* Improves splitting with a possibility to quickly change the original line amount.
* (AX2012) Support Azure AD. 

### Release 14 (2017-04-04)
Applies to D365O

**New**

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
1. Sign in and locate 'Resource Groups' in the menu. Find the resource group to be removed.
2. Open, press 'Delete' and follow instructions.
3. Locate 'App Registrations' in the menu. Find app, press 'Delete' and follow instructions.

