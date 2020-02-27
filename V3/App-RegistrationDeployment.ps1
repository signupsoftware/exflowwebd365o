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
    [string]$AppServicePlan

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

#region Download the zip-file
$PackageValidation = $True

If ($ExFlowUserSecret) {
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Checking package"
    Write-Output "--------------------------------------------------------------------------------"

    $packageURL = (New-Object System.Net.Webclient).DownloadString("$($ConfigurationData.PackageURL)/Packages?s=" + $ExFlowUserSecret + "&v=" + $PackageVersion)

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
If (-not($WebApp = Get-AzWebApp -Name $DeploymentName -ErrorAction SilentlyContinue)) {
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
If(!($IsNewDeployment)) {
    If ($WebApp.ResourceGroup -ne $ResourceGroup) {
        Write-Warning "Resource group of existing webapp: $($WebApp.ResourceGroup) does not match with resourcegroup specified in parameters"
    }
    If (($WebApp.ServerFarmId -replace '(?s)^.*\/', '') -ne $AppServicePlan) {
        Write-Warning "App Service Plan of existing webapp: $($WebApp.ServerFarmId -replace '(?s)^.*\/', '') does not match with App Service Plan specified in parameters"
    }
}

$TemplateParameters = @{
    Deployment                = $DeploymentName
    AppServicePlanSKU             = $MachineSize
    #ResourceGroupName             = $ResourceGroup
    #TemplateFile                  = "$($RepoURL)WebSite.json"
    PackageUri                    = $packageURL
    #WebSiteName                   = $DeploymentName
    #StorageAccountName            = $StorageName
    AppServicePlanName             = $AppServicePlan
    #aad_ClientId                  = $AzureRmADApplication.ApplicationId
    #aad_ClientSecret              = $psadKeyValue
    #aad_TenantId                  = $aad_TenantId
    #aad_PostLogoutRedirectUri     = "https://$($DeploymentName).$($ConfigurationData.AzureRmDomain)/close.aspx?signedout=yes"
    Dynamics365Uri             = "https://$($DynamicsAXApiId)"
    #StorageConnection             = "DefaultEndpointsProtocol=https;AccountName=$($StorageName);AccountKey=$($Keys[0].Value);"
    #KeyValueStorageConnection     = "DefaultEndpointsProtocol=https;AccountName=$($StorageName);AccountKey=$($Keys[0].Value);"
}
"$($RepoURL)WebSite.json"
New-AzResourceGroupDeployment -TemplateParameterObject $TemplateParameters -TemplateUri "$($RepoURL)WebSite.json" -Name "abc" -ResourceGroupName $ResourceGroup -Verbose

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

