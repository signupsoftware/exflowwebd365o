# Important! Do not use Powershell ISE
Powershell ISE has been deprecated and some issues has started to appear for users attempting to run the deployment script with Powershell ISE.

Use the regular Powershell console or VS Code for future deployments.

For more information check out: [Microsofts documentation](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise?view=powershell-7.2#support)


# Changes to Azure AD Application permissions
The API for Azure Active Directory Graph is being retired in June 30, 2022
As of publishing of this notice both V2 and V3 scripts have been updated to use the new Microsoft Graph API when creating new applications.

According to [Microsofts documentation](https://docs.microsoft.com/en-us/graph/migrate-azure-ad-graph-app-registration) as well as correspondence from the Microsoft Support no changes should be needed to be done to the currently registered/consented applications.

however we recommend that you update the permissions to reflect correctly with the new API.

# V2
Updating the API permissions on existing applications are not supported by the script.
You can update the permissions and create a new consent by following this [guide](https://github.com/signupsoftware/exflowwebd365o/tree/master/MSGraphAPI).

# V3
The application will apply the new permissions on existing application when running the script again, after the script is done please go to the azure portal and re-apply the Admin consent or follow the guide for V2.

___

# ExFlow web for Microsoft Dynamics 365 for Finance and Operations
ExFlow web for *Microsoft Dynamics 365 for Finance and Operations* runs in Azure as a fully scalable *Azure App Service*. ExFlow web is deployed into the tenant’s Azure environment as a Resource Group that contains a Web Site and a Storage account. The website is further connected to the Azure AD and Microsoft Dynamics 365 for Finance and Operations thru a so-called App Registration and communicates with Microsoft Dynamics 365 for Finance and Operations using the same security technology that Microsoft Dynamics 365 for Finance and Operations uses namely Azure AD and OAuth 2.0.

## PowerShell deployment script - NEW VERSION
We have a new version of the script called [V3](https://github.com/signupsoftware/exflowwebd365o/tree/master/V3) that we recommend for new deployments. If you wish to continue using the previous versions of the script see [V1](https://github.com/signupsoftware/exflowwebd365o/tree/master/V1) or [V2](https://github.com/signupsoftware/exflowwebd365o/tree/master/V2)

News in this version (V3) of the script: 
* Updated to use the new Azure Module. (Az Module - Requires install)
* Removes local dependency of DLL's by using AZ Cli instead. (Requires install)
    * New Registry method allows for extended usability of the Service Principal.
* Connects webapp to a Signup Hosted storage account for automatic updates.
    * Updates are now pushed to a storage account each month and will be automatically installed on your web app when restarted after time of release.
* Adds support to install multiple web apps to one resource group. [Details in V3](https://github.com/signupsoftware/exflowwebd365o/blob/master/V3)
* Adds support to install multiple web apps to one ASP when used together with the ResouceGroup parameter. [Details in V3](https://github.com/signupsoftware/exflowwebd365o/blob/master/V3)
* Adds support for Storage Account CORS rules when using custom domains. (Storage CORS will no longer be cleared when running the script again)
* AppControlMergeFile settings are moved from Kudu to "Application Settings" in portal.
* Adds support to run the script Azure Portal Cloud Shell. [Details in V3](https://github.com/signupsoftware/exflowwebd365o/blob/master/V3)



## Installation and updates
ExFlow web is installed by running the following PowerShell script. See also ([Run-Deploy.ps1](https://github.com/signupsoftware/exflowwebd365o/blob/master/V3/Run-Deploy.ps1)) in *Powershell ISE*. 

* Note: To update and existing V2 deployment to V3 simply install the new modules and change your current Scripts $RepoURL parameter to:
  * $RepoURL                   = "https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/V3/" 

```powershell
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



```

The script installs all required Azure components into an Azure Resource Group. During installation, the web app is registered to communicate with the Microsoft Dynamics 365 for Finance and Operations API (web services). **Note that to apply product updates you just need to restart the app service when running V3**

## Az Module
To successfully run the script you will need an updated PowerShell version. The script also depends on the Azure module, 
written by Microsoft. PowerShell and the Azure Module update frequently and updates are rarely (never) backwards compatible. Also, all versions stack up making the environment a bit unstable/unpredictable. One way of avoiding this is to uninstall modules. 
```powershell
https://docs.microsoft.com/bs-latn-ba/powershell/azure/uninstall-az-ps
```
and then reinstall the module again
```powershell
https://docs.microsoft.com/en-us/powershell/azure/install-az-ps
```
Install AZ cli:
```powershell
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
```
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-powershell

Finally close and reopen the PowerShell ISE console.

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

The “keyvalue” table exists in the Azure Storage Account and contains things like user specific settings and document comments data. 
We recommend creating a backup of this table before upgrading the application:
*	In MASE, browse to the storage account used by the application.
*	Expand the storage account, expand “Tables” and select the “keyvalues” table.
*	Press “export” in the table browser and save the .csv file to a safe location.
 
To import the CSV file follow the same steps but instead choose “import” and select the exported .csv file.

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

## Specifying what version to install when running the script.
* To use the latest version (below) run the script with variable $PackageVersion set to blank ($PackageVersion = "").
* To install an older version, omit any dots and Zeros (0). e.i:
 * $PackageVersion = "201812" for 2018.12.0
 * $PackageVersion = "201841" for 2018.4.1

### Release 2022.08

* Bug Fixes

   * Issue with cookies
   * Fixed chat names with "dash" not getting bold in messages.

### Release 2022.06
* Bug Fixes

   * Fixed sign-in issue that could result in an error if Web had lost connection to Dynamic previously.
   * Fixed issue where multiple drop-downs could be opened.

### Release 2022.05

* Improvements

   * This is a small release containing only translations for Requisition.

### Release 2022.04

* Improvements

   * Deployed new Web UI!
   * (New UI) Extended PO information pop-up
      * AppControlMergeFile setting: {FO.UsePurchaseOrderService}=true
   * Added two document types to search (Quote & Order)
   * Added additional support for resolving ExFlow User Email (Azure AD Sign-in)
   * Fixed issue with approval list
   * Fixed split issue in amount
   * (New UI) Added Simple CSV export
   * Added additional requirements for opening external links to PDF images.

* Bug Fixes

   * Fixed sign in Bug in Chrome version 97
   * Fixed UI bug when approving last invoice
   * Fixed issue when entering Job value manually
   * Fixed issue with Line Templates & Old Comments not showing
   * Fixed UI bug for Amount
   * Implemented fix for invoices that would get stuck in draft-mode
   * Fixed issue with Pdf rendering. Preview mode accepts quicker switching between documents. This could cause the pdf-viewer to display pages from two documents.

### Release 2021.09

* Bug Fixes

   * General bugfixes
   

### Release 2021.07

* Bug Fixes

   * Resolves the issue with PDF documents not showing text after Chrome updated to version 92.0.4515.107


### Release 2021.06

* Bug Fixes

   * Fixes an issue with line item charges validation.
   

### Release 2021.05

* Improvements
    * French localization.
    
* Bug Fixes
   * Improves the use of amount formulas (calculator).


### Release 2021.03

* Improvements

   * Show line misc charge values for F&O under the line amount.
   * Adds amount validation logic for line item charges.
   * Adds/Improves German localization.
   * Timezone improvements
       * Improves the display of approval dates.


### Release 2021.02

* Improvements
   * Adds tooltips for document toolbar.

* Bug Fixes
   * Fixes an issue with the Discard-button when using line templates.


### Release 2021.01

* Improvements
   * Adds the possibility to notify users about scheduled maintenance (exflow.cloud).
   * Line templates are now marked as favorite when the user clicks 'Keep'.
   * Adds configuration options to the column setup expressions (used by FO proj intercompany).
   * Adds support for project intercompany (FO).
   * System will now automatically detect if Dynamics capabilities (endpoint detection) and turn on the new chat component.
   * Project intercompany
       * Adds support for working with project intercompany in Dynamics FO. 
   * Mathematical formulas
       * In the split-view and amount field, it is now possible to use simple mathematical formulas e.g. 399.33*4/5 
   * Using % in amount field
       * It is now possible use % of the total amount in the amount field and during split. 
   * Set amount, quantity, and unit cost
       * Users can now set amount, quantity, and unit cost in the amount field or split view by using the character "x" e.g. 10x100 gives quantity=10, 
         unit cost=100, and amount=1000.

* Bug Fixes
   * Issue with detecting chat capability
       * Fixes an issue where the site could revert to using the legacy chat if Dynamics failed to respond (during endpoint detection).
   * Improves how the coding suggestion list is displayed
   * Fixes a minor issue with split 
   
   

### Release 2020.12

* Improvements
   * FO line validation
        * Line validation when forwarding is now optional.
   * Add replacer
        * Have been extended with a disable option.
        
* Bug Fixes
   * Company in search
       * System will now remember last selected company in the search feature.
   * General bugfixes


### Release 2020.9

* Bug Fixes

   * Fixes an issue where the attachments list are shown on historical documents
   

### Release 2020.8

* Bug Fixes

   * Disabled chat feature
        * Fixes an issue with the detection of Dynamics capabilities that caused many new features to be disabled, such as chat.
   * Line-type selection list
        * Fixes an issue with the line-type selection list where not all types appeared when using TAB.
   * Lines scrolling issues
        * Multiple scroll related issues have been target by this release.
   * Coding text selection
        * Fixes an issue where the line would update if you selected text in a textbox and released the mouse cursor outside the textbox.
   * Coding autofill
        * Addresses an autofill issue where values could go missing if autofill cleared the values, and the user then reapplied them.
   * Change line-type error
        * Fixes an exception when changing line-type and when the system has support for calculated VAT.
   * Line-type selection list never closes
        * When using the keyboard, the line-type selection list didn't close automatically.
  

### Release 2020.6

* Improvements
   * Adds more FO document statuses in search.
   * For Dynamics FO attachments are now saved directly to FO. Attachments can also be removed by the user that uploaded them.
   * For Dynamics FO line VAT will recalculate based on changes on line coding and amount.
   * For Dynamics FO a new lock icon indicates if a document is classified. The search feature also adds the possibility to search for classified documents.
   * For Dynamics FO the Amount in standard currency (MST) is now displayed in the search and inbox results.
   * Classified documents appear with a lock icon on the inbox along with search and sorting options. 
   
* Bug Fixes
   * Fixes that the close button on the chat feature didn't work on some mobile browsers.
   * Fixes an issue with overlapping toolbar buttons on mobile.
   * Ticket SSO 
      	* The code is now trimmed from extra white-space characters that is added by default when copying from Outlook. 


### Release 2020.5

* Improvements
   * New search criteria Order number.
   * Documents that are classified will show with a lock icon in Dynamics FO 2020.Q2.
   * Classified documents appear with a lock icon on the inbox along with search and sorting options.
   * Adds the option to search by Purchase order number.
   * Improves attachments by saving them directly to Dynamics FO. Attachments that you have uploaded can also be deleted. Available with      the FO Q2 release.
   * Purchase order column will be available with Q2 release for FO. 
   * For new users language selection have been improved to better match the browsers list of preferred languages.

* Bug Fixes
   * Fixed Chat button to close.

### Release 2020.4

* Improvements
   * Adds support for calling FO with application credentials when getting settings. This avoids that settings only gets partially
     loaded when Assigned Organization is enabled. Note that you need to register the application id in FO. 
   *	Dynamics will add links in email notifications in the upcoming releases.
   *	This release adds better support for using multiple tabs in your browser.
 
 * Bug Fixes
    *	Fixes a chat issue for Android users.
    * Fixes an issue with line column display.
    * Fixes an issue with search when working with more than one tab.
    * Fixes an issue where the wrong line could get reselected after a line was edited.
    * Increases the number of characters in hold comments.
    
### Release 2020.3

  * Improvements
     *	The default column ordering have been changed so that Vendor is the leftmost column.
     *	The calendar start day is now based on the current locale, previously it always started on Sunday.
     *	Speeds up the performance while when getting the list of approvers that previously could take some time on documents with many          lines and approvers.
     * Chat notifications show the "dots" when the list is empty.
     * Improves the chat feature by scrolling to the first unread message.
     * Improves performance by allowing more simultaneous and speeding up client calls.
     * Adds support to download Inbox and search results to Excel.

 * Bug Fixes
    * Fixes an issue in the Feb release where the previous selected document opens when search is clicked.
    * Addresses an issue in the Feb release where the list of approvers on a line only showed about 8 approvers.
    * An issue with when deleting one or more lines have been fixed.

### Release 2020.2

  * Improvements
     * Ticket SSO have been extended with variable email code length and improved security features such as the option to kill the SSO          ticket on sign out.
     
  * Bug Fixes
     * Addresses an issue when using Azure AD and user switched between multiple accounts. 

### Release 2020.1

**This release supports the Chrome 80 change to SameSite cookie behavior.**

Included in the January release there are several updates we hope will be appreciated, here are some of the highlights.
* Adds support for more columns in the search and inbox.
* Inbox now shows if a document is read/unread, overdue or if you are mentioned in chat.
*  For users that primarily review the approval list it's now possible to have the list expanded automatically.
* The system will now remember the zoom level of the PDF image.
* Also new for this release is that you now can choose between four coding views.
* To speed up the accounting process, the suggestions list will now open right when you click in the field.

Please also check out the Quick tips.

   * Improvements
      * Shows all columns in search view. 
      * Adds option to display more columns in the inbox. 
      * Adds support to trigger search when pressing Enter key. 
      *	Closes attachment and comments panels when user navigates to a new document. 
      * System now automatically expands selection lists on search and document. 
      * Adds option to always expand approvers on lines. (Toggle lock option on lines) 
      * System will remember options for PDF zoom level (if less than 100%). 
      * Adjust dashboard based on number of columns displayed in inbox grid. 
      * Improves the display of line coding by adding views: 
          * View 1 - (default) show only columns with values and scroll on overflow. 
          * View 2 - As above but wraps on overflow. 
          * View 3 - Show all columns and wrap on overflow. 
          *	View 4 - Show all columns, no wrap, hides desc for a compact display.  
      *	Highlights new documents in inbox. (D365FO) 
      *	Highlights due date in red when due date has passed. (D365FO) 
      *	Highlight document in inbox if user has been mentioned in chat.(D365FO) 
      * Adds support for grouping multiple coding columns into one. (D365FO) 
      * Adds support for tags (Document Type) in the inbox and search. (D365FO) 
      * General bugfixes

  ### Release 2019.12
  * Improvements
      * Fixed issue with chat notification.
      * Extended tooltip to show the original approver.
   ### Release 2019.11
   * Adds support for exflow-cloud as the recommended option for FO.
   * Improves inter-company features for FO.
   * Bug fixes

  ### Release 2019.10
  * Mobile
      * Fixed gray area issue when going from landscape to portrait.
   * Improvements
      * Added CrossInstance feature that will allow users to change instance from within the webapp.
      * Fixed an issue where a user could not set a replacer for the same day.
      * General bugfixes
 
 ### Release 2019.9.0.2
 
 * Stability and security.
 
 ### Release 2019.9.0
 
 * Improvement
    * Implemented partial fetch to speed up filtering for large coding columns.
    * Added some language support.
    * Automatic detection of Intercompany.
 
* Bug Fixes
   * Fixed a sortorder issue.
   * Fixed an issue where the chat panel notification would show wrong color.
   * Fixed a coding validation issue.
   * Fixed a scroll issue when reopening an invoice.
 
* Mobile UI improvements
   * Added logo for Shortcut
   * Fixed UI issue when editing ledged account
   * Fixed overlapping icons when viewing in landscape mode.
 
 
 ### Release 2019.8.0
 
 * Minor Bug Fix for line coding validation
 
 ### Release 2019.7.0
 
* Improvement
  * D365: Added Automatic detection for new chat function

* Bug Fixes
  * General Fixes for chat function
  * General Mobile scroll issues

### Release 2019.6.0

* Improvement
  * D365: Implemented new chat function. *Note: See top of github for instructions*
  * NAV/BC: Automatic Endpoint Configuration detection for easier configuration. 

* Bug Fixes
  * Fixed issue where scrollbar was not visible in attachments and comments.
  * Fixed Issue with forward approver.
  * Fixed issue where no more than 150 lines where shown

### Release 2019.4.0
* Improvements
   * Added support to deny/disable forward unless the user is first approver on all lines to approve. 
   * Fixed a bug where values in hidden coding columns would get deleted when validating.
   * Fixed an issue with the forward feature when used together with user added approvers.
   * Stability and security.
 
### Release 2019.3.0

* Improvements
   * Adds options to remove SSO tickets after sign out.
   * Restricted file types that can be uploaded. (.txt,.pdf,.zip,.png,.jpg,.doc,.docx,.xls,.xlsx,.csv,.xml)
   * Added Scandinavian languages to default languages. (English,Svenska,Norsk,Suomi,Dansk)
   * Stability and security.

### Release 2019.2.0

* Improvements
  * Added support for Azure-AD Authentication (D365FO & BC).
  * Web.Config has been revised to be more global towards different endpoints.
  * Stability and security.
  
* Bug Fixes
  * D365: Last column is gets cut off in edit.
  * Column sizes jumps.
 
### Release 2019.01.0

* Mobile UI improvements
  * The Approval button have been improved on iOS (iPhone).
  * Highlights the current approver better.

* Other improvements
  * Adds coding column width adjustment.
  * Improves how the horizontal scrollbar is displayed when viewing lines.

* Notable fixes
  * Fixes an issue where documents weren't moved from the inbox after approval.
  * Fixes an issue with attachments if filenames attached from Dynamics that contained mixed casing.
  * Fixes an issue with the PDF viewer when a user clicked the Next button.
  * Fixes an issue with the Next and Prev buttons.

### Release 2018.12.0

* Mobile UI improvements
  * The Web now includes full support for mobile editing and approval.
  * Improved menu scrolling.
  * Add and edit lines.
  * Possibility to add replacers.
  * Added possibility to split lines.
* Mobile bug fixes:
  * iOS : Approval button disappears when switching view mode (portrait/landscape).
 
* Other improvements
  * By default, we delay/skip clicks on the 'Approve all' button until the options menu has been shown, but for experienced users the click will now be allowed - speeding up the approvals.
  * Column width of the Amount field will now auto adjust.
  * Improved performance when selecting replacers.
  * Added text wrapping and scroll for Description field in edit mode.
  * Added text wrapping for Company and Vendor in search grid.
  * Templates no longer in preview.
  * Improved performance for drop-downs in columns.
  
* Notable fixes
  * Fixes issues when entering dates.
  * Visual chart label overlap.
  * Fixes issue when doc was canceled but not reloaded from Dynamics.
  * Fixes scrolling issues on iOS.

* D365FO

  * Improvement of intercompany for D365 Finance & Operations.
  * Adds new fields to invoice and order information.

### Release 2018.5.0
2018-06-08

**News**
* Improves exflow.cloud settings reload possibilities.
* Fixes an issue with app control settings for exflow.cloud.
* Fixes an issue for D365O where exception logs weren't created.
* Fixes an issue with template creation for invalid documents.
* Improves Norwegian labels.
* Improves line validation for AX.
* Improves splitting AX project lines with negative quantities.
* Bug fixes:
   * Fixes a problem with Inbox folders that could become unresponsive in IE11.
   * Fixes an issue with split templates that include lines with blank coding.

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

### If the text in the command window turns red or the script aborts something went wrong. 
1.  Press the Stop button
2.  Verify that you are using an account with enough rights to create an App registration. Note that you can't use an account with 2-factor authentication with PowerShell. Also, make sure that the account is part of the subscription admin group.
3.  Make sure that you have AzureRM installed. Open PowerShell ISE with **Run as administrator** and run the following command:
```powershell
Install-Module -Name AzureRM
```
4. If above step still fails you may have to need to upgrade to a later version of PowerShell. Go to https://msdn.microsoft.com/en-us/powershell/wmf/5.0/requirements.

### Need admin approval

In case the Azure AD setting ”Users can consent to apps accessing company data on their behalf” is set to “No” under ‘Azure Active Directory > Enterprise Applications > User Settings’, an account that is Global Administrator needs to consent the application in the tenant to allow the users to logon.

To give the application Admin consent, create an URL from the below template and have an account with Global Administrator permissions in the tenant login and allow the application access.

https://login.microsoftonline.com/{tenant}/adminconsent?  
client_id={ApplicationID}  
&state=12345  
&redirect_uri={AppURL}

After constructing the URL it should look something like this:

https://login.microsoftonline.com/b518964e-f909-4b59-800f-d9950d5786c7/adminconsent?client_id=e5247d10-9fb4-4ab9-a63d-e68f361ddb37&state=12345&redirect_uri=https://signup-demo.azurewebsites.net/inbox.aspx

Browse to the URL and sign in with a Global Admin account and accept the permissions requested.

## Remove
In the Azure Portal:
1. Sign in and locate 'Resource Groups' in the menu. Find the resource group to be removed.
2. Open, press 'Delete' and follow instructions.
3. Locate 'App Registrations' in the menu. Find app, press 'Delete' and follow instructions.

