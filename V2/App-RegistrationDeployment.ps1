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
    [string]$Prefix = "exflow",

    [Parameter(Mandatory = $False)]
    [string]$PackageVersion = "latest",

    [Parameter(Mandatory = $False)]
    [string]$MachineName = "F1",    

    [Parameter(Mandatory = $False)]
    [string]$TenantGuid,

    [Parameter(Mandatory = $False)]
    [string]$WebAppSubscriptionGuid
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
$DynamicsAXApiId = $DynamicsAXApiId.ToLower().Replace("https://","").Replace("http://","")
$DynamicsAXApiId.Substring(0, $DynamicsAXApiId.IndexOf("dynamics.com")+"dynamics.com".Length) #remove all after dynamics.com
if (!$MachineSize) { $MachineSize = "F1" }
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
    $packageSAS = "package.zip?"+$packgeUrlAr[1]
    $packageFolder = $packgeUrlAr[0].replace("/package.zip","")

    $StatusCodeWebApplication = Get-UrlStatusCode -Url  $packageURL
    If ($StatusCodeWebApplication -ne 200) { $Message = "Web package application file location could not be verified" ; Write-Warning $Message ; $PackageValidation = $False ; Try { Invoke-Logger -Message "Url: $packageURL : $StatusCodeWebApplication" -Severity W -Category "AzureRmResourceGroupDeployment" } Catch {}}
    
}
else{
    $PackageValidation = $False
}
If (!$PackageValidation) { Write-Host "" ; Write-Warning "See SignUp's GitHub for more info and help." ; return }

#endregion 

#Import used AzureRM modules to memory
If (-not (Get-Module -Name AzureRM.Automation -ErrorAction SilentlyContinue)) { Import-Module AzureRM.Automation }
If (-not (Get-Module -Name AzureRM.Profile -ErrorAction SilentlyContinue)) { Import-Module AzureRM.Profile }

#region Log in to Azure Automation
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Logging in to azure automation"
Write-Output "--------------------------------------------------------------------------------"

#Determine logon status
$AzureRmLogon = Get-AzureRmContext -ErrorAction Stop

If (!$AzureRmLogon.Account) {

    #Determine if manual subscription id was provided
    If ($WebAppSubscriptionGuid) {
        Write-Host "Subscription co-admin account"
        $AzureRmLogon = Set-AzureRmLogon -SubscriptionGuid $SubscriptionGuid
        Try { Invoke-Logger -Message "Set-AzureRmLogon -SubscriptionGuid $SubscriptionGuid" -Severity I -Category "Logon" } Catch {}
    }
    Else {
        $AzureRmLogon = Set-AzureRmLogon
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
    Else {
        #Get all subscriptions
        $SubscriptionIds = Get-AzureRmSubscription -TenantId $AzureRmLogon.Context.Tenant.Id | Select-Object Name, Id

        Try { Invoke-Logger -Message "Get-AzureRmSubscription -TenantId $($AzureRmLogon.Context.Tenant.Id) : $($SubscriptionIds.Id.count)" -Severity I -Category "Subscription" } Catch {}

        #Multiple subscriptions detected
        If ($SubscriptionIds.Id.count -gt 1) {

            $mChoices = @()
            $choice = $null
            [int]$i = 0

            #Dynamically provide all subscriptions as a choice menu
            ForEach ($SubscriptionId in $SubscriptionIds) {
                $i++
                $choice = "`$$i = new-Object System.Management.Automation.Host.ChoiceDescription '`&$($SubscriptionId.Id)','$($SubscriptionId.Id)'"
                Invoke-Expression $choice
                $mChoices += $($SubscriptionId.Name)
            }

            #Call functions to return answer from choice menu
            $answer = Get-ChoiceMenu -Choices $choices -mChoices $mChoices
        
            #Select the chosen AzureRmSubscription
            Select-AzureRmSubscription -SubscriptionId $SubscriptionIds[$answer].Id -TenantId $AzureRmLogon.Context.Tenant.Id

            Try { Invoke-Logger -Message "Select-AzureRmSubscription -SubscriptionId $($SubscriptionIds[$answer].Id) -TenantId $($AzureRmLogon.Context.Tenant.Id)" -Severity I -Category "Subscription" } Catch {}
        }
    }

    #Set AzureRM context
    Set-AzureRmContext -Context $AzureRmLogon.Context

    Try { Invoke-Logger -Message "Set-AzureRmContext -Context $($AzureRmLogon.Context)" -Severity I -Category "Context" } Catch {}

}
Else {
    #Get all subscriptions
    $SubscriptionIds = Get-AzureRmSubscription -TenantId $AzureRmLogon.Tenant.Id | Select-Object Name, Id

    Try { Invoke-Logger -Message "Get-AzureRmSubscription -TenantId $($AzureRmLogon.Tenant.Id) : $($SubscriptionIds.Id.count)" -Severity I -Category "Subscription" } Catch {}

    #Multiple subscriptions detected
    If ($SubscriptionIds.Id.count -gt 1) {
        $mChoices = @()
        $choice = $null
        [int]$i = 0

        #Dynamically provide all subscriptions as a choice menu
        ForEach ($SubscriptionId in $SubscriptionIds) {
            $i++
            $choice = "`$$i = new-Object System.Management.Automation.Host.ChoiceDescription '`&$($SubscriptionId.Id)','$($SubscriptionId.Id)'"
            Invoke-Expression $choice
            $mChoices += $($SubscriptionId.Name)
        }

        #Call functions to return answer from choice menu
        $answer = Get-ChoiceMenu -Choices $choices -mChoices $mChoices
        
        #Select the chosen AzureRmSubscription
        Select-AzureRmSubscription -SubscriptionId $SubscriptionIds[$answer].Id -TenantId $AzureRmLogon.Tenant.Id

        Try { Invoke-Logger -Message "Select-AzureRmSubscription -SubscriptionId $($SubscriptionIds[$answer].Id) -TenantId $($AzureRmLogon.Context.Tenant.Id)" -Severity I -Category "Subscription" } Catch {}
    }
    Else {
        #List currently logged on session
        $AzureRmLogon
        Try { Invoke-Logger -Message $AzureRmLogon -Severity I -Category "Logon" } Catch {}
    }
}

#Set tenant variables based on logged on session
If ($AzureRmLogon.Account.Id) {
    $SignInName = $AzureRmLogon.Account.Id
    $Subscription = "/subscriptions/$($AzureRmLogon.Subscription.Id)"
    $TenantId = $AzureRmLogon.Tenant.Id
}
Else {
    $SignInName = $AzureRmLogon.Context.Account.Id
    $Subscription = "/subscriptions/$($AzureRmLogon.Context.Subscription.Id)"
    $TenantId = $AzureRmLogon.Context.Tenant.Id
}

#Get tenant id information
If ($TenantGuid) {
    $Tenant = Get-AzureRmTenant -TenantId $TenantGuid
}
Else {
    $Tenant = Get-AzureRmTenant | Where-Object { $_.Id -eq $TenantId }
}

#Get tenant name if external user
$RoleAssignment = Get-AzureRmRoleAssignment -Scope $Subscription | Where-Object { ($_.SignInName -eq $SignInName) -or ($_.SignInName -like "$(($SignInName).Replace("@","_"))*") }

If ($RoleAssignment.SignInName -like "*#EXT#*") {
    $TenantName = ((($RoleAssignment | Select-Object -First 1 | Select-Object SignInName).SignInName).Replace("$($SignInName.Replace("@","_"))#EXT#@", "")).Replace(".onmicrosoft.com", "")
    If ($Tenant.Directory -ne $TenantName) { $Tenant.Directory = $TenantName }
}
else{
    $TenantName = $Tenant.Directory
}

$aad_TenantId = $Tenant.Id

If (!$aad_TenantId) {
    Write-Warning "A tenant id could not be found."
    return
}

Write-Output "--------------------------------------------------------------------------------"
Write-Output "Tenant information"
Write-Output "--------------------------------------------------------------------------------"

$Tenant

Try { Invoke-Logger -Message $Tenant -Severity I -Category "Tenant" } Catch {}
#endregion

#region Set deployment name for resources based on DynamicsAXApiId name
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Determining deployment name and availability"
Write-Output "--------------------------------------------------------------------------------"

$DeploymentName = Set-DeploymentName -String $DynamicsAXApiId -Prefix $Prefix

Write-Output "Deployment name: $DeploymentName"

Try { Invoke-Logger -Message "Deployment name: $DeploymentName" -Severity I -Category "Deployment" } Catch {}

If (!$DeploymentName) { Write-Warning "A deployment name could not be generated." ; return }

If (-not(Get-AzureRmResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue)) {
    $Message = "New deployment detected"
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
If ($ConfigurationData.AzureRmRoleAssignmentValidation) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Validating AzureRmRoleAssignment"
    Write-Output "--------------------------------------------------------------------------------"

    #Get AzureRmRoleAssignment for currently logged on user
    $AzureRmRoleAssignment = ($RoleAssignment).RoleDefinitionName

    $AzureRmRoleAssignment

    Try { Invoke-Logger -Message $AzureRmRoleAssignment -Severity I -Category "AzureRmRoleAssignment" } Catch {}

    Write-Output ""

    #Determine that the currently logged on user has appropriate permissions to run the script in their Azure subscription
    If (-not ($AzureRmRoleAssignment -contains "Owner") -and -not ($AzureRmRoleAssignment -contains "Contributor")) {
        Write-Host ""
        Write-Warning "Owner or contributor permissions could not be verified for your subscription."
        Write-Host ""
        Write-Warning "See SignUp's GitHub for more info and help."

        Try { Invoke-Logger -Message "Owner or contributor permissions could not be verified for your subscription" -Severity W -Category "AzureRmRoleAssignment" } Catch {}

        return
    }
}
#endregion

#region Create AzureRmResourceGroup
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

#region Create/Get AzureRmStorageAccount
If ($AzureRmResourceGroup -and -not (Get-AzureRmStorageAccount -ResourceGroupName $DeploymentName -Name $DeploymentName -ErrorAction SilentlyContinue)) {

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmStorageAccount"
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "This process may take a few minutes..."

    $AzureRmStorageAccountParams = @{
        Name              = $DeploymentName
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

    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $DeploymentName -Name $DeploymentName
    $StorageContext = New-AzureStorageContext -StorageAccountName $DeploymentName -StorageAccountKey $Keys[0].Value

    Try { Invoke-Logger -Message $Keys -Severity I -Category "AzureRmStorageAccount" } Catch {}
    Try { Invoke-Logger -Message $StorageContext -Severity I -Category "AzureRmStorageAccount" } Catch {}
}
Else {
    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $DeploymentName -Name $DeploymentName
    $StorageContext = New-AzureStorageContext -StorageAccountName $DeploymentName $Keys[0].Value

    Try { Invoke-Logger -Message $Keys -Severity I -Category "AzureRmStorageAccount" } Catch {}
    Try { Invoke-Logger -Message $StorageContext -Severity I -Category "AzureRmStorageAccount" } Catch {}
}
#endregion

#region Create AzureStorageContainer
If ($AzureRmResourceGroup -and $AzureRmStorageAccount -and -not(Get-AzureStorageContainer -Name $ConfigurationData.Storage.Container -Context $StorageContext -ErrorAction SilentlyContinue)) {

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureStorageContainer"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureStorageContainerParams = @{
        Name       = $ConfigurationData.Storage.Container
        Permission = "Off"
        Context    = $StorageContext
    }

    New-AzureStorageContainer @AzureStorageContainerParams

    Try { Invoke-Logger -Message $AzureStorageContainerParams -Severity I -Category "AzureStorageContainer" } Catch {}

}
#endregion

#region Create AzureStorageCORSRule
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
If (-not($AzureRmADApplication = Get-AzureRmADApplication -DisplayNameStartWith $DeploymentName -ErrorAction SilentlyContinue)) {

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    $azureRmModuleVersion = Get-Module -ListAvailable -Name AzureRm | Sort-Object -Descending | Select-Object -First 1

    $psadCredential = $null
    If ("$($azureRmModuleVersion.Version.Major).$($azureRmModuleVersion.Version.Minor).$($azureRmModuleVersion.Version.Build)" -le "4.2.0") {
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

    $SecurePassword = $psadKeyValue | ConvertTo-SecureString -AsPlainText -Force
    $SecurePassword | Export-Clixml $ConfigurationData.PSADCredential.ClixmlPath

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
    Write-Output "Importing PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    If (Test-Path -Path $ConfigurationData.PSADCredential.ClixmlPath -ErrorAction SilentlyContinue) {

        $SecurePassword = Import-Clixml $ConfigurationData.PSADCredential.ClixmlPath
        $psadKeyValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))

        Write-Output $psadKeyValue
        Try { Invoke-Logger -Message "Password: *****" -Severity I -Category "PSADCredential" } Catch {}
    }
    Else {
        Write-Warning "A PSADCredential could not be found, aborting"
        Try { Invoke-Logger -Message "A PSADCredential could not be found, aborting" -Severity W -Category "PSADCredential" } Catch {}
        Try { Invoke-Logger -Message "Path: $($ConfigurationData.PSADCredential.ClixmlPath)" -Severity W -Category "PSADCredential" } Catch {}
        return
    }
}
#endregion

#region Create AzureRmADServicePrincipal
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

#region Create AzureRmRoleAssignment
If ($AzureRmADApplication -and -not($AzureRmRoleAssignment = Get-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ErrorAction SilentlyContinue)) {

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmRoleAssignment"
    Write-Output "--------------------------------------------------------------------------------"

    $x = 0
    While ((-not($AzureRmRoleAssignment)) -and ($X -lt 15)) {
        $AzureRmRoleAssignment = $null
        Try {
            $AzureRmRoleAssignment = New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ErrorAction Stop
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
    skuName                       = $MachineName
    ResourceGroupName             = $DeploymentName
    TemplateFile                  = "$($RepoURL)WebSite.json"
    webApplicationPackageFolder   = $packageFolder
    WebApplicationPackageFileName = $packageSAS
    WebSiteName                   = $DeploymentName
    StorageAccountName            = $DeploymentName
    hostingPlanName               = $DeploymentName
    aad_ClientId                  = $AzureRmADApplication.ApplicationId
    aad_ClientSecret              = $psadKeyValue
    aad_TenantId                  = $aad_TenantId
    aad_PostLogoutRedirectUri     = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/close.aspx?signedout=yes"
    aad_ExternalApiId             = "https://$($DynamicsAXApiId)"
    StorageConnection             = "DefaultEndpointsProtocol=https;AccountName=$($DeploymentName);AccountKey=$($Keys[0].Value);"
    KeyValueStorageConnection     = "DefaultEndpointsProtocol=https;AccountName=$($DeploymentName);AccountKey=$($Keys[0].Value);"
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

        Write-Output "Downloading: $($ConfigurationData.RedistPath)/$($DllFile)"
        Try { Invoke-Logger -Message "Downloading: $($ConfigurationData.RedistPath)/$($DllFile)" -Severity I -Category "AzureSDK" } Catch {}

        Get-WebDownload -Source "$($ConfigurationData.RedistPath)/$($DllFile)?raw=true" -Target "$($ConfigurationData.LocalPath)\$($DllFile)"
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

$Measure.Stop()

Write-Output ""
Write-Output ""
Write-Output "Browse to the following URL to initialize the application:"
Write-Host "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -ForegroundColor Green
Try { Invoke-Logger -Message "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -Severity I -Category "WebApplication" } Catch {}

Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Completed in $(($Measure.Elapsed).TotalSeconds) seconds"
Try { Invoke-Logger -Message "Completed in $(($Measure.Elapsed).TotalSeconds) seconds" -Severity I -Category "Summary" } Catch {}