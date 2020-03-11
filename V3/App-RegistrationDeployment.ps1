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
    [string]$UseApiName,

    [Parameter(Mandatory = $False)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $False)]
    [string]$AppServicePlan,

    [Parameter(Mandatory = $False)]
    [bool]$ShowAdvancedMenu = $false

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

function Show-Menu
{
     param (
           [string]$Title = 'Advanced Menu'
     )
     #cls
     Write-Host "================ $Title ================"
    
     Write-Host "1 : Select Resource Group Name"
     Write-Host "2 : Select App Service Plan Name"
     Write-Host "3 : I'm feeling lucky; specify your own deployment name"
     Write-Host "Q : Press 'Q' to quit."
     Write-Host "9 : Overwrite deployment; Reruns the template deployment as if new installation : Press '9' for this option."
}


Clear-Host
If ($ShowAdvancedMenu) {
    do
    {
        Show-Menu
        $input = Read-Host "Please make a selection"
        if ($input -eq "q") {
            cls
            Write-host "You have made the following advanced selections: "
            "Resource Group: $resourceGroup"
            "App Service Plan: $AppServicePlan"
            "DeploymentName: $DeploymentName"
        }
        switch ($input)
        {
            '1' {
                    cls
                    [string]$ResourceGroup = Read-Host "Enter Resource Group Name"
            } '2' {
                    cls
                    [string]$AppServicePlan = Read-Host "Enter App Service Plan Name"
            } '3' {
                    cls
                    [string]$DeploymentName = Read-Host "Enter Deployment Name"
            } 'q' {
                    break
            }
        }
        #pause
    }
    until ($input -eq 'q')
}
function Get-AzCachedAccessToken() {
    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }

    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
#Web client download options
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
if (-not($MachineSize)) { $MachineSize = "B1 Basic" }
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
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Checking PowerShell & Azure Cli version and modules"
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
$AzCliVersion = az --version
If ($AzCliVersion) {
    $AzCliVersion = $AzCliVersion[0] | Select-String '((?:\d{1,3}\.){1,3}\d{1,3})' | ForEach-Object {
        $_.Matches[0].Groups[1].Value
     }
     $AzCliVersion = [System.Version]::Parse($AzCliVersion)
     If ($AzCliVersion -lt $ConfigurationData.AzCli) {
        Write-Warning "Az Cli must be updated. (Installed version: $($AzCliVersion.tostring()) ; Required: $($ConfigurationData.AzCli)"
        Write-Warning "`tInstall-Module -Name $($Module.Name) -AllowClobber -Force"
        Try { Invoke-Logger -Message "Module $($Module.Name) must be updated" -Severity W -Category "PSModule" } Catch {}
        $hasErrors = $True
     } else {
         Write-Output "Az Cli version $($AzCliVersion.ToString()) is valid"
     }
} else {
    $Message = "Az Client is not installed "
    Write-Warning $Message
    Write-Warning "Run the following command as admin and relaunch your powershell session: `nInvoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'"
    Try { Invoke-Logger -Message $Message -Severity W -Category "Az Cli" } Catch {}
    $hasErrors = $True
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
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $packageURL = (New-Object System.Net.Webclient).DownloadString("$($ConfigurationData.PackageURL)/Packages?s=" + $ExFlowUserSecret + "&v=" + $PackageVersion)

    Write-Output "Package URL: " 
    Write-Output $packageURL
    Write-Output ""

    Try { Invoke-Logger -Message "Package URL: $packageURL" -Severity I -Category "Package" } Catch {}

    $packgeUrlAr = $packageURL.Split("?")
    $packageSAS = "package.zip?" + $packgeUrlAr[1]
    $packageFolder = $packgeUrlAr[0].replace("/package.zip", "")

}
else {
    $PackageValidation = $False
}
If (!$PackageValidation) { Write-Host "" ; Write-Warning "See SignUp's GitHub for more info and help." ; return }
Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Logging in to Azure"
Write-Output "--------------------------------------------------------------------------------"
$AzLogin = $null
$AzContext = Get-AzContext
If ($WebAppSubscriptionGuid) {
    If (-not($AzContext)) {
        Write-Output "Please login to Az Module(Opens in new window):"
        $AzLogin = Login-AzAccount -Subscription $WebAppSubscriptionGuid
        $AzLogin
    } elseif ($AzContext.Subscription.id -ne $WebAppSubscriptionGuid) {
        Write-Output "Current context is not set to same subscription as specified in script"
        $AvailableSubscriptions = Get-AzSubscription
        $selectSubscription = $AvailableSubscriptions | where {$_.subscriptionId -eq $WebAppSubscriptionGuid}
        If ($selectSubscription) {
            $AzLogin =  Select-AzSubscription $selectSubscription.SubscriptionId
        } else {
            Write-Warning "selected user does not have access to subscription $WebAppSubscriptionGuid or is running in a cloud shell in the wrong tenant"
        }
    }
} elseif (!$WebAppSubscriptionGuid) {
    If (-not($AzContext)) {
        Write-Output "Please login to Az Module(Opens in new window):"
        $AzLogin = Login-AzAccount
        $AzLogin
    }
    $AvailableSubscriptions = Get-AzSubscription | Select-Object Name, Id
    Try { Invoke-Logger -Message "Get-AzureRmSubscription : $($AvailableSubscriptions.Id.count)" -Severity I -Category "Subscription" } Catch {}

    #Multiple subscriptions detected
    If ($AvailableSubscriptions.Id.count -gt 1) {
        Write-Output ""
        Write-Output "Multiple Azure subscriptions found:"
        $AvailableSubscriptions | Format-Table | Out-String|% {Write-Host $_}
        Write-Output ""
        $answer = Read-Host -Prompt 'Enter Subscription id:'
        #Select the chosen AzureRmSubscription
        Select-AzSubscription $answer
        Try { Invoke-Logger -Message "Select-AzureRmSubscription -SubscriptionId $answer" -Severity I -Category "Subscription" } Catch {}
    }
}
$AzContext = Get-AzContext
#$AzLogin
If (!$AzContext) { Try { Invoke-Logger -Message "Logon to Azure failed" -Severity W -Category "Logon" } Catch {} ; return }
else 
{Write-Output "Logged in to subscription: $($AzContext.Subscription.Name) as user: $($AzContext.Account)"}
$ErrorActionPreference = "SilentlyContinue"
$AzCliLogin = az account show | ConvertFrom-Json
If ($TenantGuid) {
    If (-not($AzCliLogin)) {
        Write-Output "Please login to Az Cli With an account that has global admin(Opens in new window):"
        $AzCliLogin = az login --tenant $TenantGuid --allow-no-subscriptions | ConvertFrom-Json
    } elseif ($AzCliLogin.tenantId -ne $TenantGuid) {
        $AzCliLoginList = az account list | ConvertFrom-Json
        $AzCliTenantMatch = $AzCliLoginList | where {$_.tenantId -eq $TenantGuid} | Select-Object -First 1
        If ($AzCliTenantMatch) {
            Az Account Set --subscription $AzCliTenantMatch.id
        } elseif (-not($AzCliTenantMatch)) {
            write-output "selected user does not have access to tenant $TenantGuid  or is running in a cloud shell in the wrong tenant"
        }
    }
} elseif (!$TenantGuid) {
    If (-not($AzCliLogin)) {
        $AzCliLogin = az login | ConvertFrom-Json
    }
    $AzCliLoginList = az account list | ConvertFrom-Json 
    If ($AzCliLoginList.tenantId.count -gt 1) {
        Write-Output ""
        Write-Output "Multiple Azure tenants found:"
        Write-Output $AzCliLoginList | Select-Object name, tenantId | ft
        Write-Output ""
        $answer = Read-Host -Prompt 'Enter tenant id:'
        $AzCliLogin = az account set --subscription ($AzCliLoginList | where {$_.tenantId -eq $answer} | Select-Object -First 1).id
        #$AvailableTenants = $AzCliLogin | Select-Object name, tenantId
    }
}
If (!$AzCliLogin) { Try { Invoke-Logger -Message "Logon to Azure failed" -Severity W -Category "Logon" } Catch {} ; return }
else 
{Write-Output "Logged in to tenant: $($AzCliLogin.tenantId) as user: $($AzCliLogin.user.name)"}
$ErrorActionPreference = "Continue"
#region Set deployment name for resources based on DynamicsAXApiId name
#$ctx = Switch-Context -UseDeployContext $True
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Determining deployment name and availability"
Write-Output "--------------------------------------------------------------------------------"
If (!$DeploymentName) {
    If ($UseApiName -eq "true") {
        $DeploymentName = $Prefix + $DynamicsAXApiSubdomain
    }
    Else {
        $DeploymentName = Set-DeploymentName -String $DynamicsAXApiId -Prefix $Prefix 
    }
}
Write-Output "Deployment name: $DeploymentName"

Try { Invoke-Logger -Message "Deployment name: $DeploymentName" -Severity I -Category "Deployment" } Catch {}

If (!$DeploymentName) { Write-Warning "A deployment name could not be generated." ; return }
$IsNewDeployment = $False
If (-not($WebApp = Get-AzWebApp -Name $DeploymentName -ErrorAction SilentlyContinue)) {
    $dnsNameUnique = $true
    $Message = "New deployment detected"
    $IsNewDeployment = $True
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
    If (-not(Test-AzDnsAvailability -DomainNameLabel $DeploymentName -Location $Location)) {
        $Message = "A unique Az DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
        $dnsNameUnique = $false
    }
    If (-not((Get-AzStorageAccountNameAvailability -Name $DeploymentName).NameAvailable)) {
        $Message = "A unique Az Storage Account name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
        $dnsNameUnique = $false
    }
    $continueDeployment = $false
    try {
        ([System.Net.Dns]::GetHostEntry("$($DeploymentName).$($ConfigurationData.AzureRmDomain)")) #| out-null
    } catch {
        $continueDeployment = $true
    }
    If ($continueDeployment -eq $false) {
        $Message = "A unique DNS name could not be automatically determined"
        Write-Warning $Message
        Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
        $dnsNameUnique = $false
    }
    if (-not($dnsNameUnique)) {
        Write-warning "Deployment Name did not resolve to be unique, exiting script"
        break
    }
}
Else {
    $Message = "Existing deployment detected"
    Write-Output $Message
    Try { Invoke-Logger -Message $Message -Severity I -Category "Deployment" } Catch {}
    Write-Output ""
}
#endregion 
If (-not($ResourceGroup)) {$ResourceGroup = $DeploymentName}
If (-not($AppServicePlan)) {$AppServicePlan = $DeploymentName}
If(-not(Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue)) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmResourceGroup"
    Write-Output "--------------------------------------------------------------------------------"
    Try {
        New-AzResourceGroup -Name $ResourceGroup -Location $Location
    } Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmResourceGroup" } Catch {}
        return
    }
    $x = 0
    While ((-not(Get-AzResourceGroup -Name $ResourceGroup -Location $Location -ErrorAction SilentlyContinue)) -and ($X -lt 10)) {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmResourceGroup status for $(5*$x) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    Write-Output $AzureRmResourceGroup
    Try { Invoke-Logger -Message $AzureRmResourceGroup -Severity I -Category "AzureRmResourceGroup" } Catch {}
} else {
    Try { Invoke-Logger -Message $AzureRmResourceGroup -Severity I -Category "AzureRmResourceGroup" } Catch {}
}
If(!($IsNewDeployment)) {
    If ($WebApp.ResourceGroup -ne $ResourceGroup) {
        Write-Warning "Resource group of existing webapp: $($WebApp.ResourceGroup) does not match with resourcegroup specified in parameters"
    }
    If (($WebApp.ServerFarmId -replace '(?s)^.*\/', '') -ne $AppServicePlan) {
        Write-Warning "App Service Plan of existing webapp: $($WebApp.ServerFarmId -replace '(?s)^.*\/', '') does not match with App Service Plan specified in parameters"
    }
}

If(-not($AzAadApp = az ad app list --display-name $ResourceGroup <#Get-AzADApplication -DisplayName $ResourceGroup -ErrorAction SilentlyContinue#>)) {
    Write-Output ""

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmADApplication"
    Write-Output "--------------------------------------------------------------------------------"

    $psadCredential = New-Object Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential
    $startDate = Get-Date
    $psadCredential.StartDate = $startDate
    $psadCredential.EndDate = $startDate.AddYears($ConfigurationData.PSADCredential.Years)
    $psadCredential.KeyId = [guid]::NewGuid()
    $psadKeyValue = Set-AesKey
    $psadCredential.Password = $psadKeyValue
    Try { Invoke-Logger -Message $psadCredential -Severity I -Category "PSADCredential" } Catch {}

    try {
    <#
    $AzAadApp = New-AzADApplication -DisplayName $ResourceGroup `
                        -IdentifierUris "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)" `
                        -HomePage "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" `
                        -ReplyUrls "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" `
                        -PasswordCredentials $psadCredential
    #>
    $ErrorActionPreference = "Continue"
    $requiredresourceaccesses = '[{"resourceAppId": "00000002-0000-0000-c000-000000000000","resourceAccess": [{"id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6","type": "Scope"}]},{"resourceAppId": "00000015-0000-0000-c000-000000000000","resourceAccess": [{"id": "6397893c-2260-496b-a41d-2f1f15b16ff3","type": "Scope"},{"id": "a849e696-ce45-464a-81de-e5c5b45519c1","type": "Scope"},{"id": "ad8b4a5c-eecd-431a-a46f-33c060012ae1","type": "Scope"}]}]' | convertto-json
    $error.Clear()
    $ReTry = 0
    do
    {
        $AzAadApp = az ad app create --display-name $ResourceGroup --identifier-uris ("https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx") --password $psadCredential.Password --reply-urls ("https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx") --required-resource-accesses $requiredresourceaccesses --end-date ($(get-date).AddYears(20)) --credential-description $DeploymentName
        if (!($AzAadApp)) {
            write-output "no app found"
            $error
            #Write-output $error[1]
            If ($error[1].Exception.Message -eq "ERROR: Insufficient privileges to complete the operation.") {
                Write-Warning "Failed setting Azure AD App: $($error[1].Exception.Message)"
                $SwitchAcc = Read-Host "Do you want to login to Az Cli with another account? (y/n)"
                If ($SwitchAcc -eq "y") {
                    Write-Output "Please login with an account that has permissions to create applications(Opens in new tab)"
                    $AzCliLogin = az login --tenant $TenantGuid --allow-no-subscriptions | ConvertFrom-Json
                } elseif ($SwitchAcc -eq "n") {
                    write-warning "Exiting script"
                    break
                } else {
                    write-warning "No input recived, exiting script"
                    break
                }
            } elseif ($error[0].Exception.Message -eq "ERROR: No subscription found. Run 'az account set' to select a subscription.") {
                Write-output "Az Cli is logged in but could not find an active subscription"
                $AzCliLogin = az login --tenant $TenantGuid --allow-no-subscriptions | ConvertFrom-Json
            } else {
                Write-Warning "Failed setting Azure AD App: $($error[1].Exception.Message)"
                Write-Error $error[0].Exception.Message
            }
            Write-output "logged in as $($AzCliLogin[0].user.name)"
        } else {
            If ($AzCliLogin.user.name -ne $AzContext.Account) {
                "Write-output logging out of Az Account $($AzCliLogin[0].user.name)"
                az logout --username  ($AzCliLogin[0].user.name)
            }
        }
        #pause
        $ReTry++
    }
    until ($AzAadApp -or ($ReTry -ge 5))
    If ($ReTry -ge 5) {
        Write-Error "Attempted to create Az App more than 5 times, exiting script"
    }
    } Catch {
        Write-Error $_
        Try { Invoke-Logger -Message $_ -Severity E -Category "AzureRmADApplication" } Catch {}
    }
} else {
    $setAzAppCred = $AzAadApp | ConvertFrom-Json

    $psadCredential = New-Object Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential
    $startDate = Get-Date
    $psadCredential.StartDate = $startDate
    $psadCredential.EndDate = $startDate.AddYears($ConfigurationData.PSADCredential.Years)
    $psadCredential.KeyId = [guid]::NewGuid()
    $psadKeyValue = Set-AesKey
    $psadCredential.Password = $psadKeyValue
    az ad app credential reset --id $setAzAppCred.appId --password $psadCredential.Password --end-date ($(get-date).AddYears(20)) --credential-description $DeploymentName
}
If ($AzAadApp) {
    #$AzAadApp
    $AzAadApp = $AzAadApp | ConvertFrom-Json
    write-output $azAadApp | select displayName, ObjectId, identifierUris, homepage, appId, availableToOtherTenants, appPermissions, replyUrls, objectType
    Write-output ""
    Write-Output $psadCredential
    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Deploying Azure Resource Manager Template"
    Write-Output "--------------------------------------------------------------------------------"
    $psadKeyValue
    $TemplateParameters = @{
        ApplicationName                = $DeploymentName
        AppServicePlanSKU             = $MachineSize
        PackageUri                    = $packageURL
        AppServicePlanName             = $AppServicePlan
        aad_ClientId                  = $AzAadApp.appId
        aad_ClientSecret              = $psadKeyValue
        aad_TenantId                  = $TenantGuid
        #aad_PostLogoutRedirectUri     = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/close.aspx?signedout=yes"
        Dynamics365Uri             = "https://$($DynamicsAXApiId)"
    }

    "$($RepoURL)WebSite.json"
    New-AzResourceGroupDeployment -TemplateParameterObject $TemplateParameters -TemplateUri "$($RepoURL)WebSite.json" -Name "abc" -ResourceGroupName $ResourceGroup -Verbose
    $Measure.Stop()

    Write-Output ""
    Write-Output ""
    Write-Output "Browse to the following URL to initialize the application:"
    Write-Host "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -ForegroundColor Green
    Try { Invoke-Logger -Message "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/inbox.aspx" -Severity I -Category "WebApplication" } Catch {}
}
Write-Output ""
#Write-Output "Send this URL to Signup to allow read access to exflowdiagnostics container in $StorageName :"
#Write-host "$SASUri" -ForegroundColor Green
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Completed in $(($Measure.Elapsed).TotalSeconds) seconds"
Try { Invoke-Logger -Message "Completed in $(($Measure.Elapsed).TotalSeconds) seconds" -Severity I -Category "Summary" } Catch {}
