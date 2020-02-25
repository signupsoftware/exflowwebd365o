#Parameters for input as arguments or parameters
param(
    [Parameter(Mandatory = $True)]
    [string]$Location,

    [Parameter(Mandatory = $True)]
    [string]$Security_Admins,

    [Parameter(Mandatory = $True)]
    [string]$DynamicsAXApiId,

    [Parameter(Mandatory = $True)]
    [string]$RepoURL,

    [Parameter(Mandatory = $True)]
    [string]$ExFlowUserSecret,

    [Parameter(Mandatory = $False)]
    [string]$Prefix="",

    [Parameter(Mandatory = $False)]
    [string]$PackageVersion,

    [Parameter(Mandatory = $False)]
    [string]$MachineSize,    

    [Parameter(Mandatory = $False)]
    [string]$TenantGuid,

    [Parameter(Mandatory = $False)]
    [string]$WebAppSubscriptionGuid,

    [Parameter(Mandatory = $False)]
    [string]$UseApiName

)

Function Get-UrlStatusCode {
    Param
    (
        [ValidateNotNullOrEmpty()]
        [String]$Url
    )
    [int]$StatusCode = $null
    try {
        $StatusCode = (Invoke-WebRequest -Uri $Url -UseBasicParsing -DisableKeepAlive).StatusCode
        if (-not( $Url.StartsWith("https://")) ) {
            $StatusCode = 200
        }
    }
    catch [Net.WebException] {
        $StatusCode = [int]$_.Exception.Response.StatusCode
    }
    return $StatusCode
}

Clear-Host

#We client download options
$Webclient = New-Object System.Net.Webclient
$Webclient.UseDefaultCredentials = $true
$Webclient.Proxy.Credentials = $Webclient.Credentials
$Webclient.Encoding = [System.Text.Encoding]::UTF8
$Webclient.CachePolicy = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)

#Start measuring time to complete script
$Measure = [System.Diagnostics.Stopwatch]::StartNew()

#Import script parameters and variables from a configuration data file
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Importing configuration"
Write-Output "--------------------------------------------------------------------------------"

$DependencyValidation = $True

#Download the Helper-Module
$StatusCodeHelper = Get-UrlStatusCode -Url "$($RepoURL)Helper-Module.ps1"
If ($StatusCodeHelper -ne 200) {
    Write-Warning "Helper-Module location could not be verified."
    Write-Warning "Url: $($RepoURL)Helper-Module.ps1"
    Write-Warning "StatusCode: $StatusCodeHelper"
    $DependencyValidation = $False
}
Else {
    $Webclient.DownloadString("$($RepoURL)Helper-Module.ps1") | Invoke-Expression
}

#Download and convert the configuration data file as Hash Table
$StatusCodeConfiguration = Get-UrlStatusCode -Url "$($RepoURL)ConfigurationData.psd1"
If ($StatusCodeConfiguration -ne 200) {
    Write-Warning "ConfigurationData.psd1 location could not be verified."
    Write-Warning "Url: $($RepoURL)ConfigurationData.psd1"
    Write-Warning "StatusCode: $StatusCodeConfiguration"
    $DependencyValidation = $False
}
Else {
    [hashtable]$ConfigurationData = Get-ConfigurationDataAsObject -ConfigurationData ($Webclient.DownloadString("$($RepoURL)ConfigurationData.psd1") | Invoke-Expression)
}
#Clean input
$DynamicsAXApiId = $DynamicsAXApiId.ToLower().Replace("https://", "").Replace("http://", "")
$DynamicsAXApiId.Substring(0, $DynamicsAXApiId.IndexOf("dynamics.com") + "dynamics.com".Length) #remove all after dynamics.com
$DynamicsAXApiSubdomain = $DynamicsAXApiId.Substring(0, $DynamicsAXApiId.IndexOf("."))
if (-not($MachineSize)) { $MachineSize = "B1" }
if ($Prefix) { $Prefix = $Prefix.ToLower() }
If (-not($PackageVersion)) {$PackageVersion = "latest"}
#If (-not($ConfigurationData.RedistPath)) { $ConfigurationData.RedistPath = $RepoURL }

#Setup log file
[String]$LogFile = "$($ConfigurationData.LocalPath)\$($ConfigurationData.LogFile)"

Write-Host "LogFile: $LogFile" -ForegroundColor Green

Try { Invoke-Logger -Message "Location: $Location" -Severity I -Category "Parameters" } Catch {}
Try { Invoke-Logger -Message "Security_Admins: $Security_Admins" -Severity I -Category "Parameters" } Catch {}
Try { Invoke-Logger -Message "DynamicsAXApiId: $DynamicsAXApiId" -Severity I -Category "Parameters" } Catch {}
Try { Invoke-Logger -Message "RepoURL: $RepoURL" -Severity I -Category "Parameters" } Catch {}

Try { Invoke-Logger -Message "Helper-Module: $($RepoURL)Helper-Module.ps1" -Severity I -Category "Helper-Module" } Catch {}
Try { Invoke-Logger -Message "ConfigurationData.psd1: $($RepoURL)ConfigurationData.psd1" -Severity I -Category "Configuration" } Catch {}

Try { Invoke-Logger -Message $ConfigurationData -Severity I -Category "Configuration" } Catch {}

If (!$DependencyValidation) { Write-Host "" ; Write-Warning "See SignUp's GitHub for more info and help." ; return }

Write-Output "Helper-Module: $($RepoURL)Helper-Module.ps1"
Write-Output "ConfigurationData: $($RepoURL)ConfigurationData.psd1"
Write-Output ""

#region Checking PowerShell version and modules
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Checking PowerShell version and modules"
Write-Output "--------------------------------------------------------------------------------"

#Call function to verify installed modules and versions against configuration data file
<#
$hasErrors = Get-RequiredModules -Modules $ConfigurationData.Modules

#Verify installed PowerShell version against the configuration data file
If ($PSVersionTable.PSVersion -lt $ConfigurationData.PowerShell.Version) {
    $Message = "PowerShell must be updated to at least $($ConfigurationData.PowerShell.Version)."
    Write-Warning $Message
    Try { Invoke-Logger -Message $Message -Severity W -Category "PowerShell" } Catch {}
    $hasErrors = $True
}
Else {
    $Message = "PowerShell version $($PSVersionTable.PSVersion) is valid."
    Write-Host $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "PowerShell" } Catch {}
    Write-Host ""
}


If ($hasErrors) {
    Write-Host ""
    Write-Warning "See SignUp's GitHub for more info and help."
    break
}
#endregion
#>
#region Download the zip-file
$PackageValidation = $True

If ($ExFlowUserSecret) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Checking package"
    Write-Output "--------------------------------------------------------------------------------"

    $packageURL = (New-Object System.Net.Webclient).DownloadString("$($ConfigurationData.PackageURL)/packages?s=" + $ExFlowUserSecret + "&v=" + $PackageVersion)

    Write-Output "Package URL: " 
    Write-Output $packageURL
    Write-Output ""

    Try { Invoke-Logger -Message "Package URL: $packageURL" -Severity I -Category "Package" } Catch {}

    $packgeUrlAr = $packageURL.Split("?")
    $packageSAS = "package.zip?" + $packgeUrlAr[1]
    $packageFolder = $packgeUrlAr[0].replace("/package.zip", "")

    #$StatusCodeWebApplication = Get-UrlStatusCode -Url  $packageURL
    #If ($StatusCodeWebApplication -ne 200) { $Message = "Web package application file location could not be verified" ; Write-Warning $Message ; $PackageValidation = $False ; Try { Invoke-Logger -Message "Url: $packageURL : $StatusCodeWebApplication" -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
    
}
else {
    $PackageValidation = $False
}
If (!$PackageValidation) { Write-Host "" ; Write-Warning "See SignUp's GitHub for more info and help." ; return }

#region Set deployment name for resources based on DynamicsAXApiId name
#$ctx = Switch-Context -UseDeployContext $True
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Determining deployment name and availability"
Write-Output "--------------------------------------------------------------------------------"
If ($UseApiName -eq "true") {
    $DeploymentName = $Prefix + $DynamicsAXApiSubdomain
}
Else {
    $DeploymentName = Set-DeploymentName -String $DynamicsAXApiId -Prefix $Prefix 
}
Write-Output "Deployment name: $DeploymentName"

Try { Invoke-Logger -Message "Deployment name: $DeploymentName" -Severity I -Category "Deployment" } Catch {}

If (!$DeploymentName) { Write-Warning "A deployment name could not be generated." ; return }
$IsNewDeployment = $False
If (-not(Get-AzResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue)) {
    $Message = "New deployment detected"
    $IsNewDeployment = $True
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
    If (-not(Test-AzDnsAvailability -DomainNameLabel $DeploymentName -Location $Location)) {
        $Message = "A unique Az DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    }
    If (Resolve-DnsName -Name "$($DeploymentName).$($ConfigurationData.AzureRmDomain)" -ErrorAction SilentlyContinue) {
        $Message = "A unique DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    }
}
Else {
    $Message = "Existing deployment detected"
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
}
#endregion

Write-Output "--------------------------------------------------------------------------------"
Write-Output "Validating AzureRmRoleAssignment"
Write-Output "--------------------------------------------------------------------------------"

#Get AzureRmRoleAssignment for currently logged on user
$AzureRmRoleAssignment = ($RoleAssignment).RoleDefinitionName

$AzureRmRoleAssignment

Try { Invoke-Logger -Message $AzureRmRoleAssignment -Severity I -Category "AzureRmRoleAssignment" } Catch {}

Write-Output "-"

Write-Output $AzureRmRoleAssignment

#Determine that the currently logged on user has appropriate permissions to run the script in their Azure subscription
If (-not ($AzureRmRoleAssignment -contains "Owner") -and -not ($AzureRmRoleAssignment -contains "Contributor")) {
    Write-Host ""
    Write-Warning "Owner or contributor permissions could not be verified for your subscription."
    Write-Host ""
    Write-Warning "See SignUp's GitHub for more info and help."

    Try { Invoke-Logger -Message "Owner or contributor permissions could not be verified for your subscription" -Severity W -Category "AzureRmRoleAssignment" } Catch {}

    #return
}
#endregion

#endregion 
<#
#Import used AzureRM modules to memory
If (-not (Get-Module -Name AzureRM.Automation -ErrorAction SilentlyContinue)) { Import-Module AzureRM.Automation }
If (-not (Get-Module -Name AzureRM.Profile -ErrorAction SilentlyContinue)) { Import-Module AzureRM.Profile }

Function Switch-Context() {
    param(
        [Parameter(Mandatory = $True)]
        $UseDeployContext,
        [Parameter(Mandatory = $False)]
        $SkipSubscriptionSelection = $False
    )
    if ($UseDeployContext) {
        $armctx = Set-AzureRmContext -Context $AzureRmLogon.Context
        If ($AzureRmLogonSelectedSubscriptionId -and -not $SkipSubscriptionSelection) {
            $selsub = Select-AzureRmSubscription -SubscriptionId $AzureRmLogonSelectedSubscriptionId
        }
    }
    else {
        $armctx = Set-AzureRmContext -Context $AzureRmTenantLogon.Context
        If ($AzureRmTenantLogonSelectedSubscriptionId -and -not $SkipSubscriptionSelection ) {
            $selsub = Select-AzureRmSubscription -SubscriptionId $AzureRmTenantLogonSelectedSubscriptionId
        }
    }

    Try { Invoke-Logger -Message "Set-AzureRmContext -Context $($armctx)" -Severity I -Category "Context" } Catch {}    
    return Get-AzureRmContext
}
 
#region Log in to Azure Automation
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Logging in to azure"
Write-Output "--------------------------------------------------------------------------------"
$AzureRmLogon = @{Account = $null}
$AzureRmLogonSelectedSubscriptionId = $WebAppSubscriptionGuid
$AzureRmTenantLogon = @{Account = $null}
$AzureRmTenantLogonSelectedSubscriptionId = ""
#Determine logon status
If (!$AzureRmLogon.Account) {
    Write-Host "Sign-in with your Subscription account (opens in another win):"
    #Determine if manual subscription id was provided
    If ($WebAppSubscriptionGuid) {
        $AzureRmLogon = Set-AzureRmLogon -SubscriptionGuid $WebAppSubscriptionGuid
        $AzureRmTenantLogon = $AzureRmLogon
        Try { Invoke-Logger -Message "Set-AzureRmLogon -SubscriptionGuid $WebAppSubscriptionGuid" -Severity I -Category "Logon" } Catch {}
    }
    Else {
        $AzureRmLogon = Set-AzureRmLogon
        $AzureRmTenantLogon = $AzureRmLogon
        Try { Invoke-Logger -Message "Set-AzureRmLogon" -Severity I -Category "Logon" } Catch {}
    }

    #If logon failed abort script
    If (!$AzureRmLogon) { Try { Invoke-Logger -Message "Logon to Azure failed" -Severity W -Category "Logon" } Catch {} ; return }

    #Determine Azure subscription
    If (-not($AzureRmLogon.Context.Subscription)) {
        Write-Warning "The account is not linked to an Azure subscription! Please add account to a subscription in the Azure portal."
        Try { Invoke-Logger -Message "The account is not linked to an Azure subscription! Please add account to a subscription in the Azure portal." -Severity W -Category "Subscription" } Catch {}
        return
    }
    ElseIf (!$AzureRmLogonSelectedSubscriptionId) {
        #Get all subscriptions
        $SubscriptionIds = Get-AzureRmSubscription | Select-Object Name, Id

        Try { Invoke-Logger -Message "Get-AzureRmSubscription : $($SubscriptionIds.Id.count)" -Severity I -Category "Subscription" } Catch {}

        #Multiple subscriptions detected
        If ($SubscriptionIds.Id.count -gt 1) {
            Write-Output ""
            Write-Output "Multiple Azure subscriptions found:"
            Write-Host $SubscriptionIds
            Write-Output ""
            $answer = Read-Host -Prompt 'Enter Subscription id:'
            #Select the chosen AzureRmSubscription
            $AzureRmLogonSelectedSubscriptionId = $answer
            Try { Invoke-Logger -Message "Select-AzureRmSubscription -SubscriptionId $answer" -Severity I -Category "Subscription" } Catch {}
        }
    }    
}
$AzureRmTenantLogonSelectedSubscriptionId = $AzureRmLogonSelectedSubscriptionId #same subscription for app reg  is assumed

Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Tenant information"
Write-Output "--------------------------------------------------------------------------------"
#Set tenant variables based on logged on session
If ($AzureRmLogon.Account.Id) {
    $SignInName = $AzureRmLogon.Account.Id
    $Subscription = "/subscriptions/$($AzureRmLogon.Subscription.Id)"
}
Else {
    $SignInName = $AzureRmLogon.Context.Account.Id
    $Subscription = "/subscriptions/$($AzureRmLogon.Context.Subscription.Id)"
}

#Get tenant id information
try {
    Write-Output ""
    Write-Output "Tenants found:"
    Write-Output ""
    Write-Output (Get-AzureRmTenant)
    $answer = "no"
    If (!$TenantGuid) {
        $answer = Read-Host -Prompt 'Is the tenant (used by Dynamics) i.e. your AD in this list? Type y/n:'
    }
    else {
        $tenants = Get-AzureRmTenant | Where-Object Id -eq $TenantGuid 
        if ($tenants.length>0) {
            $answer = 'yes'
        }
    }
    if ($answer -eq "y" -or $answer -eq "Y" -or $answer -eq "yes" -or $answer -eq "Yes") {
 
        If (!$TenantGuid) {
            $SubscriptionIds = Get-AzureRmSubscription | Select-Object Name, Id, TenantId
        }
        else {
            $SubscriptionIds = Get-AzureRmSubscription | Where-Object TenantId -eq $TenantGuid | Select-Object Name, Id, TenantId
        }
        If ($SubscriptionIds.Id.count -gt 1) { 
            #more than one sub prompt to select
            Write-Output "Subscriptions:"
            Write-Output (Get-AzureRmSubscription)
            $answer = Read-Host -Prompt 'Enter SubscriptionId (connected to the tenant):'
            $AzureRmTenantLogonSelectedSubscriptionId = $answer
        }
        elseif ($SubscriptionIds.Id.count -eq 1) {
            $AzureRmTenantLogonSelectedSubscriptionId = $SubscriptionIds.Id
        }
        
    }
    else {
        ## the tenant is not in current subscription we must switch account
        Write-Output "Sign-in with your company account (Azure AD):"
        $AzureRmTenantLogon = Set-AzureRmLogon
        $ctx = Switch-Context -UseDeployContext $False -SkipSubscriptionSelection $True
        Write-Output ""
        Write-Output "Tenants found:"
        Write-Output ""
        Write-Output (Get-AzureRmTenant)
        Write-Output ""
        If (!$TenantGuid) {
            $SubscriptionIds = Get-AzureRmSubscription | Select-Object Name, Id, TenantId
        }
        else {
            $SubscriptionIds = Get-AzureRmSubscription | Where-Object TenantId -eq $TenantGuid | Select-Object Name, Id, TenantId
        }
        If ($SubscriptionIds.Id.count -gt 1) { 
            #more than one sub prompt to select
            Write-Output "Subscriptions:"
            Write-Output (Get-AzureRmSubscription)
            $answer = Read-Host -Prompt 'Enter SubscriptionId (connected to the tenant):'
            $AzureRmTenantLogonSelectedSubscriptionId = $answer
        }
        elseif ($SubscriptionIds.Id.count -eq 1) {
            $AzureRmTenantLogonSelectedSubscriptionId = $SubscriptionIds.Id
        }
       
    }
                
    $Tenant = (Switch-Context -UseDeployContext $False).Tenant
    $TenantName = $Tenant.Directory
    If (!$TenantName -and $Tenant) {
        $Tenant = Get-AzureRmTenant | Where-Object Id -eq $Tenant.Id #Bug in RM where dir is not set on context
        $TenantName = $Tenant.Directory
    }
}
catch {
    Write-Error $_
    Write-Warning "Tenant could not be retrived. Use paramter TenantGuid in complex env with multipe subscriptions. In the second promp for credentials use a Windows AD user i.e. @companydomain.com user"
    Write-Warning "Script aborted."
    return
}

$aad_TenantId = $Tenant.Id

If (!$aad_TenantId) {
    Write-Warning "A tenant id could not be found."
    return
}
Write-Output ""

Try { Invoke-Logger -Message $Tenant -Severity I -Category "Tenant" } Catch {}
#endregion
#region Checkpoint
Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Checkpoint"
Write-Output "--------------------------------------------------------------------------------"
Write-Output "App registration tenant:"
Write-Output ($Tenant)
Write-Output "Deployment subscription:"
Write-Output (Switch-Context -UseDeployContext $True).Subscription
Write-Output ""
$answer = Read-Host -Prompt "Is this correct? (y/n)"
if ($answer -eq "n") {
    Write-Warning "Script was canceled"
    return
}
#endregion
#region Set deployment name for resources based on DynamicsAXApiId name
$ctx = Switch-Context -UseDeployContext $True
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Determining deployment name and availability"
Write-Output "--------------------------------------------------------------------------------"
If ($UseApiName -eq "true") {
    $DeploymentName = $Prefix + $DynamicsAXApiSubdomain
}
Else {
    $DeploymentName = Set-DeploymentName -String $DynamicsAXApiId -Prefix $Prefix 
}
Write-Output "Deployment name: $DeploymentName"

Try { Invoke-Logger -Message "Deployment name: $DeploymentName" -Severity I -Category "Deployment" } Catch {}

If (!$DeploymentName) { Write-Warning "A deployment name could not be generated." ; return }
$IsNewDeployment = $False
If (-not(Get-AzureRmResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue)) {
    $Message = "New deployment detected"
    $IsNewDeployment = $True
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
    If (-not(Test-AzureRmDnsAvailability -DomainNameLabel $DeploymentName -Location $Location)) {
        $Message = "A unique AzureRm DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    }
    If (Resolve-DnsName -Name "$($DeploymentName).$($ConfigurationData.AzureRmDomain)" -ErrorAction SilentlyContinue) {
        $Message = "A unique DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    }
}
Else {
    $Message = "Existing deployment detected"
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
}
#endregion

#region Verify AzureRmRoleAssignment to logged on user
$ctx = Switch-Context -UseDeployContext $True

If ($ConfigurationData.AzureRmRoleAssignmentValidation -and !$TenantGuid) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Validating AzureRmRoleAssignment"
    Write-Output "--------------------------------------------------------------------------------"

    #Get AzureRmRoleAssignment for currently logged on user
    $AzureRmRoleAssignment = ($RoleAssignment).RoleDefinitionName

    $AzureRmRoleAssignment

    Try { Invoke-Logger -Message $AzureRmRoleAssignment -Severity I -Category "AzureRmRoleAssignment" } Catch {}

    Write-Output "-"
    
    Write-Output $AzureRmRoleAssignment

    #Determine that the currently logged on user has appropriate permissions to run the script in their Azure subscription
    If (-not ($AzureRmRoleAssignment -contains "Owner") -and -not ($AzureRmRoleAssignment -contains "Contributor")) {
        Write-Host ""
        Write-Warning "Owner or contributor permissions could not be verified for your subscription."
        Write-Host ""
        Write-Warning "See SignUp's GitHub for more info and help."

        Try { Invoke-Logger -Message "Owner or contributor permissions could not be verified for your subscription" -Severity W -Category "AzureRmRoleAssignment" } Catch {}

        #return
    }
}
#endregion

#region Create AzureRmResourceGroup
$ctx = Switch-Context -UseDeployContext $True

If (-not($AzureRmResourceGroup = Get-AzureRmResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue)) {

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmResourceGroup"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureRmResourceGroupParams = @{
        Name     = $DeploymentName
        Location = $Location
    }

    Try {
        $AzureRmResourceGroup = New-AzureRmResourceGroup @AzureRmResourceGroupParams -ErrorAction Stop
    }
    Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmResourceGroup" } Catch {}
        return
    }  

    $x = 0
    While ((-not(Get-AzureRmResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue)) -and ($X -lt 10)) {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmResourceGroup status for $(5*$x) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    Write-Output $AzureRmResourceGroup
    Try { Invoke-Logger -Message $AzureRmResourceGroup -Severity I -Category "AzureRmResourceGroup" } Catch {}

}
Else {
    Try { Invoke-Logger -Message $AzureRmResourceGroup -Severity I -Category "AzureRmResourceGroup" } Catch {}
}
#endregion
$StorageName = Get-AlphaNumName -Name $DeploymentName.replace("exflow", "") -MaxLength 24

If (-not ($IsNewDeployment) -and $AzureRmResourceGroup -and -not (Get-AzureRmStorageAccount -ResourceGroupName $DeploymentName -Name $StorageName -ErrorAction SilentlyContinue)) {
   $StorageName = Get-AlphaNumName -Name $DeploymentName -MaxLength 24
}
#region Create/Get AzureRmStorageAccount
$ctx = Switch-Context -UseDeployContext $True
If ($AzureRmResourceGroup -and -not (Get-AzureRmStorageAccount -ResourceGroupName $DeploymentName -Name $StorageName -ErrorAction SilentlyContinue)) {

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmStorageAccount"
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "This process may take a few minutes..."

    $AzureRmStorageAccountParams = @{
        Name              = $StorageName
        ResourceGroupName = $DeploymentName
        Type              = $ConfigurationData.Storage.Type
        Location          = $Location
    }

    Try {
        $AzureRmStorageAccount = New-AzureRmStorageAccount @AzureRmStorageAccountParams -ErrorAction Stop
    }
    Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmStorageAccount" } Catch {}
        return
    }

    Write-Output $AzureRmStorageAccount

    Try { Invoke-Logger -Message $AzureRmStorageAccount -Severity I -Category "AzureRmStorageAccount" } Catch {}

    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $DeploymentName -Name $StorageName
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $Keys[0].Value

    Try { Invoke-Logger -Message $Keys -Severity I -Category "AzureRmStorageAccount" } Catch {}
    Try { Invoke-Logger -Message $StorageContext -Severity I -Category "AzureRmStorageAccount" } Catch {}
}
Else {
    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $DeploymentName -Name $StorageName
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageName $Keys[0].Value

    Try { Invoke-Logger -Message $Keys -Severity I -Category "AzureRmStorageAccount" } Catch {}
    Try { Invoke-Logger -Message $StorageContext -Severity I -Category "AzureRmStorageAccount" } Catch {}
}
#endregion

#region Create AzureStorageCORSRule
$ctx = Switch-Context -UseDeployContext $True
If ($StorageContext) {
    $ConfigurationData.CorsRules.AllowedOrigins = ($ConfigurationData.CorsRules.AllowedOrigins).Replace("[DeploymentName]", $DeploymentName)

    $cRules = Get-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext

    $cUpdate = $False
    ForEach ($CorsRule in $ConfigurationData.CorsRules.Keys) {
        If (!([string]$cRules.$CorsRule -eq [string]$ConfigurationData.CorsRules.$CorsRule)) {
            $cUpdate = $True
            Break
        }
    }

    If ($cUpdate) {
        Write-Output ""
        Write-Output "--------------------------------------------------------------------------------"
        Write-Output "Create AzureStorageCORSRule"
        Write-Output "--------------------------------------------------------------------------------"

        Try {
            Set-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext -CorsRules $ConfigurationData.CorsRules -ErrorAction Stop
            $GetAzureStorageCORSRule = Get-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext

            Write-Host $GetAzureStorageCORSRule
            Write-Output ""

            Try { Invoke-Logger -Message $GetAzureStorageCORSRule -Severity I -Category "AzureStorageCORSRule" } Catch {}

        }
        Catch {
            Write-Error $_
            Try { Invoke-Logger -Message $_ -Severity E -Category "AzureStorageCORSRule" } Catch {}
        }
    }
}
#endregion

#region Create AzureRmADApplication
$ctx = Switch-Context -UseDeployContext $False
If (-not($AzureRmADApplication = Get-AzureRmADApplication -DisplayName $DeploymentName -ErrorAction SilentlyContinue)) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    $azureRmModuleVersion = (Get-Module -ListAvailable -Name AzureRm).Version | Sort-Object -Descending | Select-Object -First 1

    $psadCredential = $null
    If ("$($azureRmModuleVersion.Major).$($azureRmModuleVersion.Minor).$($azureRmModuleVersion.Build)" -le "4.2.0") {
        $psadCredential = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADPasswordCredential
    }
    Else {
        $psadCredential = New-Object Microsoft.Azure.Graph.RBAC.Version1_6.ActiveDirectory.PSADPasswordCredential
    }

    $startDate = Get-Date
    $psadCredential.StartDate = $startDate
    $psadCredential.EndDate = $startDate.AddYears($ConfigurationData.PSADCredential.Years)
    $psadCredential.KeyId = [guid]::NewGuid()
    $psadKeyValue = Set-AesKey
    $psadCredential.Password = $psadKeyValue

    # $SecurePassword = $psadKeyValue | ConvertTo-SecureString -AsPlainText -Force
    # $SecurePassword | Export-Clixml $ConfigurationData.PSADCredential.ClixmlPath

    Write-Output $psadCredential
    Try { Invoke-Logger -Message $psadCredential -Severity I -Category "PSADCredential" } Catch {}
    Write-Output ""

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmADApplication"
    Write-Output "--------------------------------------------------------------------------------"


    $AzureRmADApplicationParams = @{
        DisplayName         = $DeploymentName
        HomePage            = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx"
        IdentifierUris      = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)"
        ReplyUrls           = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx"
        PasswordCredentials = $psadCredential
    }

    Try {
        $AzureRmADApplication = New-AzureRmADApplication @AzureRmADApplicationParams -ErrorAction Stop
        Write-Output $AzureRmADApplication
        Try { Invoke-Logger -Message $AzureRmADApplication -Severity I -Category "AzureRmADApplication" } Catch {}
    }
    Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmADApplication" } Catch {}
    }   
}
Else {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    #$ctx = Switch-Context -UseDeployContext $True
    $psadKeyValue = Set-AesKey
    $securestring = $psadKeyValue | convertto-securestring -AsPlainText -Force
    Try {
        $AzureRMApplicationPassword = New-AzureRmADAppCredential -ApplicationId $AzureRmADApplication.ApplicationId -Password $securestring -EndDate ((get-date).AddYears($ConfigurationData.PSADCredential.Years)) -ErrorAction Stop
        if ($AzureRMApplicationPassword) {
            $slot = Get-AzureRmWebAppSlot -Name $DeploymentName -Slot production -ResourceGroupName $DeploymentName 
            $appSettings = $slot.SiteConfig.AppSettings
            $newAppSettings = @{}
            ForEach ($item in $appSettings) {
                $newAppSettings[$item.Name] = $item.Value
            }
            $newAppSettings.aad_ClientSecret = $psadKeyValue
            Set-AzureRmWebApp -AppSettings $newAppSettings -name $slot.name -ResourceGroupName $slot.ResourceGroup | Out-Null
        }
    } catch {
        Write-Warning ("Error occurred when creating new credentials for Application with AppId: " + $AzureRmADApplication.ApplicationId)
        Write-warning ("Error: " + $Error[0].Exception)
        $slot = Get-AzureRmWebAppSlot -Name $DeploymentName -Slot production -ResourceGroupName $DeploymentName
        $psadKeyValue = ($slot.SiteConfig.AppSettings |  Where-Object {$_.Name -eq "aad_ClientSecret"} | Select-Object Value -First 1).Value
    }
}
#endregion

#region Create AzureRmADServicePrincipal
$ctx = Switch-Context -UseDeployContext $False
If ($AzureRmADApplication -and -not($AzureRmADServicePrincipal = Get-AzureRmADServicePrincipal -SearchString $AzureRmADApplication.DisplayName -ErrorAction SilentlyContinue)) {

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmADServicePrincipal"
    Write-Output "--------------------------------------------------------------------------------"

    Try {
        $AzureRmADServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $AzureRmADApplication.ApplicationId -ErrorAction Stop
        Try { Invoke-Logger -Message $AzureRmADServicePrincipal -Severity I -Category "AzureRmADServicePrincipal" } Catch {}
    }
    Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmADServicePrincipal" } Catch {}
    } 

    $x = 0
    While ($X -lt 6) {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmADServicePrincipal completion for $(30-(5*$x)) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    $x = 0
    While ((-not($AzureRmADServicePrincipal = Get-AzureRmADServicePrincipal -SearchString $AzureRmADApplication.DisplayName -ErrorAction SilentlyContinue)) -and ($X -lt 10)) {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmADServicePrincipal status for $(5*$x) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    Write-Output $AzureRmADServicePrincipal
}
Else {
    Try { Invoke-Logger -Message $AzureRmADServicePrincipal -Severity I -Category "AzureRmADServicePrincipal" } Catch {}
}
#endregion
<#
#region Create AzureRmRoleAssignment
$ctx = Switch-Context -UseDeployContext $False
If ($AzureRmADApplication -and -not($AzureRmRoleAssignment = Get-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ResourceGroupName $DeploymentName -ErrorAction SilentlyContinue)) {

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmRoleAssignment"
    Write-Output "--------------------------------------------------------------------------------"

    $x = 0
    While ((-not($AzureRmRoleAssignment)) -and ($X -lt 15)) {
        $AzureRmRoleAssignment = $null
        Try {
            $AzureRmRoleAssignment = New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ResourceGroupName $DeploymentName -ErrorAction Stop
            Try { Invoke-Logger -Message $AzureRmRoleAssignment -Severity I -Category "AzureRmRoleAssignment" } Catch {}
        }
        Catch {
            Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmRoleAssignment status for 5 seconds" -ForegroundColor "cyan"
            Start-Sleep 5
            $x++
        }
    }

    Write-Output $AzureRmRoleAssignment
}
Else {
    Try { Invoke-Logger -Message $AzureRmRoleAssignment -Severity I -Category "AzureRmRoleAssignment" } Catch {}
}
#endregion

#region Deploy Azure Resource Manager Template
$ctx = Switch-Context -UseDeployContext $True
Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Deploying Azure Resource Manager Template"
Write-Output "--------------------------------------------------------------------------------"

[bool]$ParamValidation = $True
If (!$DeploymentName) { $Message = "Deployment name parameter could not be determined" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}

$StatusCodeWebSite = Get-UrlStatusCode -Url "$($RepoURL)WebSite.json" 
If ($StatusCodeWebSite -ne 200) { $Message = "Template file location could not be verified" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message "Url: $($RepoURL)WebSite.json : $StatusCodeWebSite" -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}

If (!$AzureRmADApplication.ApplicationId) { $Message = "Application ID parameter could not be verified" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
If (!$psadKeyValue) { $Message = "PSADCredential secret could not be verified" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
If (!$AzureRmADApplication.ApplicationId) { $Message = "AAD client ID parameter could not be verified" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
If (!$aad_TenantId) { $Message = "AAD tenant ID parameter could not be verified" ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
If (!$Keys[0].Value) { $Message = "Storage SAS key could not be verified." ; Write-Warning $Message ; $ParamValidation = $False ; Try { Invoke-Logger -Message $Message -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}

If (!$ParamValidation) { Write-Host "" ; Write-Warning "See SignUp's GitHub for more info and help." ; return }

$TemplateParameters = @{
    Name                          = $DeploymentName
    skuName                       = $MachineSize
    ResourceGroupName             = $DeploymentName
    TemplateFile                  = "$($RepoURL)WebSite.json"
    webApplicationPackageFolder   = $packageFolder
    WebApplicationPackageFileName = $packageSAS
    WebSiteName                   = $DeploymentName
    StorageAccountName            = $StorageName
    hostingPlanName               = $DeploymentName
    aad_ClientId                  = $AzureRmADApplication.ApplicationId
    aad_ClientSecret              = $psadKeyValue
    aad_TenantId                  = $aad_TenantId
    aad_PostLogoutRedirectUri     = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/close.aspx?signedout=yes"
    aad_ExternalApiId             = "https://$($DynamicsAXApiId)"
    StorageConnection             = "DefaultEndpointsProtocol=https;AccountName=$($StorageName);AccountKey=$($Keys[0].Value);"
    KeyValueStorageConnection     = "DefaultEndpointsProtocol=https;AccountName=$($StorageName);AccountKey=$($Keys[0].Value);"
}

If ($Security_Admins) {
    $TemplateParameters.Add("Security_Admins", $Security_Admins)
}

Try { Invoke-Logger -Message $TemplateParameters -Severity I -Category "AzureRmResourceGroupDeployment" } Catch {}

New-AzureRmResourceGroupDeployment @TemplateParameters -Verbose

$x = 0
While ($X -lt 3) {
    Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmResourceGroupDeployment for $(15-(5*$x)) seconds" -ForegroundColor "cyan"
    Start-Sleep 5
    $x++
}
#endregion

#region Web App registration with Microsoft Graph REST Api
$ctx = Switch-Context -UseDeployContext $False

$SDKHeader = $True
ForEach ($DllFile in $ConfigurationData.AzureSDK.Dlls) {
    If (!(Test-Path -Path "$($ConfigurationData.LocalPath)\$($DllFile)" -ErrorAction SilentlyContinue)) {
        If ($SDKHeader) {
            Write-Output ""
            Write-Output "--------------------------------------------------------------------------------"
            Write-Output "Downloading Azure SDK DLL:s"
            Write-Output "--------------------------------------------------------------------------------"
            $SDKHeader = $False
        }

        Write-Output "Downloading: $($ConfigurationData.RedistPath)$($DllFile)"
        Try { Invoke-Logger -Message "Downloading: $($ConfigurationData.RedistPath)$($DllFile)" -Severity I -Category "AzureSDK" } Catch {}
        if ($ConfigurationData.RedistPath.Contains("http")) {
            Get-WebDownload -Source "$($ConfigurationData.RedistPath)$($DllFile)?raw=true" -Target "$($ConfigurationData.LocalPath)\$($DllFile)"
        }
        else {
            Get-WebDownload -Source "$($ConfigurationData.RedistPath)$($DllFile)" -Target "$($ConfigurationData.LocalPath)\$($DllFile)"
        }
    }
}

$newGuid = [guid]::NewGuid()
$guidToBytes = [System.Text.Encoding]::UTF8.GetBytes($newGuid)

$mySecret = @{
    "type"      = $ConfigurationData.ApplicationRegistration.Type
    "usage"     = "Verify"
    "endDate"   = [DateTime]::UtcNow.AddDays($ConfigurationData.ApplicationRegistration.Days).ToString("u").Replace(" ", "T")
    "keyId"     = $newGuid
    "startDate" = [DateTime]::UtcNow.AddDays(-1).ToString("u").Replace(" ", "T")
    "value"     = [System.Convert]::ToBase64String($guidToBytes)
}

$restPayload = @{
    "keyCredentials" = @($mySecret)
}

$restPayload.Add("requiredResourceAccess", @($ConfigurationData.RequiredResourceAccess, $ConfigurationData.RequiredResourceAccessAZ))

$restPayload = ConvertTo-Json -InputObject $restPayload -Depth 4

$token = Get-AuthorizationToken -TenantName $TenantName

Write-Output "ExpiresOn: $($token.ExpiresOn.LocalDateTime)"
Try { Invoke-Logger -Message $token -Severity I -Category "Token" } Catch {}

$authorizationHeader = @{
    "Content-Type"  = "application/json"
    "Authorization" = $token.AccessToken
}

$restUri = "https://$($ConfigurationData.GraphAPI.URL)/$($TenantName)/applications/$($AzureRmADApplication.ObjectId)?api-version=$($ConfigurationData.GraphAPI.Version)"
$restResourceAccess = Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Method GET | Select-Object -ExpandProperty requiredResourceAccess

Try { Invoke-Logger -Message "GET: $restUri" -Severity I -Category "Graph" } Catch {}
Try { Invoke-Logger -Message $restResourceAccess -Severity I -Category "Graph" } Catch {}

If ($restResourceAccess.resourceAppId -notcontains $ConfigurationData.RequiredResourceAccess.resourceAppId) {
    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Configure application settings"
    Write-Output "--------------------------------------------------------------------------------"

    Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Body $restPayload -Method PATCH -Verbose

    Try { Invoke-Logger -Message "PATCH" -Severity I -Category "Graph" } Catch {}
}
Else {
    Try { Invoke-Logger -Message $restResourceAccess.resourceAppId -Severity I -Category "Graph" } Catch {}

    ForEach ($Resource in $restResourceAccess) {
        If ($resourceAccess.resourceAppId -eq $ConfigurationData.RequiredResourceAccess.resourceAppId) {
            $resourceAccess = ($Resource | Select-Object -ExpandProperty resourceAccess).id

            $updateResourceAccess = $False
            ForEach ($id in $ConfigurationData.RequiredResourceAccess.resourceAccess.id) {
                If ($resourceAccess -notcontains $id) {
                    $updateResourceAccess = $True
                    Break
                }
            }

            If ($updateResourceAccess) {
                Write-Output ""
                Write-Output "--------------------------------------------------------------------------------"
                Write-Output "Configure application settings"
                Write-Output "--------------------------------------------------------------------------------"

                Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Body $restPayload -Method PATCH -Verbose

                Try { Invoke-Logger -Message "PATCH" -Severity I -Category "Graph" } Catch {}
            }
        }
    }
}

Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Cleaning up Azure SDK DLL:s"
Write-Output "--------------------------------------------------------------------------------"

ForEach ($DllFile in $ConfigurationData.AzureSDK.Dlls) {
    Write-Output "Removing: $($ConfigurationData.LocalPath)\$($DllFile)"
    Try { Invoke-Logger -Message "Removing: $($ConfigurationData.LocalPath)\$($DllFile)" -Severity I -Category "AzureSDK" } Catch {}
    Remove-Item -Path "$($ConfigurationData.LocalPath)\$($DllFile)" -Force -ErrorAction SilentlyContinue
}
#endregion

#Region Create SASToken
#$Key2Context = New-AzureStorageContext -StorageAccountName $StorageName $Keys[1].Value
#$SASURI = New-AzureStorageContainerSASToken -Name exflowdiagnostics -Permission rl -IPAddressOrRange "85.24.197.82" <#Signup -Context $Key2Context -FullUri -ExpiryTime (get-date).AddYears(1)
#endregion
#>
$Measure.Stop()

Write-Output ""
Write-Output ""
Write-Output "Browse to the following URL to initialize the application:"
Write-Host "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -ForegroundColor Green
Try { Invoke-Logger -Message "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -Severity I -Category "WebApplication" } Catch {}

Write-Output ""
#Write-Output "Send this URL to Signup to allow read access to exflowdiagnostics container in $StorageName :"
#Write-host "$SASUri" -ForegroundColor Green
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Completed in $(($Measure.Elapsed).TotalSeconds) seconds"
Try { Invoke-Logger -Message "Completed in $(($Measure.Elapsed).TotalSeconds) seconds" -Severity I -Category "Summary" } Catch {}

