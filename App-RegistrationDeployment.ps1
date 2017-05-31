#Parameters for input as arguments or parameters
param(
    [Parameter(Mandatory=$True)]
    [string]$Location,

    [Parameter(Mandatory=$True)]
    [string]$Security_Admins,

    [Parameter(Mandatory=$True)]
    [string]$DynamicsAXApiId,

    [Parameter(Mandatory=$True)]
    [string]$ExFlowUserSecret,

    [Parameter(Mandatory=$True)]
    [string]$Prefix,

    [Parameter(Mandatory=$True)]
    [string]$PackageVersion,

    [Parameter(Mandatory=$True)]
    [string]$TenantGuid
)

#Function to get authorization token for communication with the Microsoft Graph REST API
Function GetAuthorizationToken
{
    param
    (
            [Parameter(Mandatory=$true)]
            $TenantName
    )
    $adal             = "$($FilePath.Replace("\\","\"))\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms        = "$($FilePath.Replace("\\","\"))\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId         = "1950a258-227b-4e31-a9cf-717495945fc2" 
    $resourceAppIdURI = "https://graph.windows.net"
    $authority        = "https://login.windows.net/$TenantName"
    $creds            = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential" -ArgumentList $($Credential.UserName),$($Credential.GetNetworkCredential().password)
    $authContext      = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $authResult       = $authContext.AcquireToken($resourceAppIdURI, $clientId, $creds)
    return $authResult
}

#Function to create AesManagedObject for the PSADCredential
Function Create-AesManagedObject($key, $IV) {
    $aesManaged           = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode      = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding   = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize   = 256
    If ($IV) {
        If ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        Else {
            $aesManaged.IV = $IV
        }
    }
    If ($key) {
        If ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        Else {
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}

#Function to create AesKey for the PSADCredential
Function Create-AesKey() {
    $aesManaged = Create-AesManagedObject 
    $aesManaged.GenerateKey()
    [System.Convert]::ToBase64String($aesManaged.Key)
}

Clear-Host
$Measure = [System.Diagnostics.Stopwatch]::StartNew()
If (!$PackageVersion){
    $PackageVersion="latest"
}
$HasErrors = ""
#region jb
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Checking PowerShell version and modules"
Write-Output "--------------------------------------------------------------------------------"
$azrm = Get-Module -ListAvailable -Name AzureRM
If (!$azrm){
    $HasErrors = "Module AzureRM is not installed (use command: Install-Module -Name AzureRM and reopen PowerShell editor). Script aborted!"
}
ElseIf ($azrm.Version -lt "4.0.2"){
    $HasErrors = "Module AzureRM $($azrm.Version) should updated (use command: Install-Module -Name AzureRM and reopen PowerShell editor). Script aborted!"
}
ElseIf ($PSVersionTable.PSVersion -lt "5.0.0"){
    $HasErrors = "PowerShell could be updated from $($PSVersionTable.PSVersion) to > 5.0. See SignUp's GitHub for more info and help."
}
Else{
    Write-Output "Modules and PowerShell versions are valid"
}
Write-Output "PowerShell version: "$($PSVersionTable.PSVersion)
Write-Output ""
Write-Output "AzureRM version: "$($azrm.Version)
Write-Output ""

If ($HasErrors){
    Write-Warning $HasErrors
    return 
}

#get the zip-file
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Checking package"
Write-Output "--------------------------------------------------------------------------------"

$packageURL = (New-Object System.Net.Webclient).DownloadString('https://exflowpackagemanager.azurewebsites.net/packages?s='+$ExFlowUserSecret+'&v='+$PackageVersion)
Write-Output "Package URL: " 
Write-Output $packageURL
Write-Output ""
$packgeUrlAr = $packageURL.Split("?")
$packageSAS = "package.zip?"+$packgeUrlAr[1]
$packageFolder = $packgeUrlAr[0].replace("/package.zip","")

#endregion

#region Log in to Azure Automation
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Logging in to azure automation"
Write-Output "--------------------------------------------------------------------------------"

[PSCredential]$Credential = (Get-Credential -Message "Azure tenant administrator account")
If (!($Credential)) { Write-Output "Script aborted..." ; exit }

Import-Module AzureRM.Automation
$login = Login-AzureRmAccount  -Credential $Credential
If (-not($login)){
    $HasErrors = "Login failed. Script aborted."
}
ElseIf (-not($login.Context.Subscription)){
    $HasErrors =  "This account doesn't have a subscription! Please add subscription in the Azure portal. Scrip aborted."
}
$Tenant = Get-AzureRmTenant
If ($TenantGuid){
    $Tenant = Get-AzureRmTenant -TenantId $TenantGuid
}

$aad_TenantId = $Tenant.Id
$tenantName = $Tenant.Directory

Write-Output $login.Context

If (!$aad_TenantId){
    $HasErrors = "Tenant not found. Script aborted."
}
#endregion

If ($HasErrors){
    Write-Warning $HasErrors
    return 
}


#region Determine AzureRmDnsAvailability
$md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$utf8 = New-Object -TypeName System.Text.UTF8Encoding
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($DynamicsAXApiId)))
If ($Prefix){
    $hash = $Prefix+$hash
}
$_TenantId = "exflow$(($hash.ToLower()).Replace('-','').Substring(0,18))"
If (-not(Get-AzureRmResourceGroup -Name $_TenantId -Location $Location -ErrorAction SilentlyContinue) -and `
   (-not(Test-AzureRmDnsAvailability -DomainNameLabel $_TenantId -Location $Location)))
{
    For ($x=1; $x -le 9; $x++)
    {
        If (Test-AzureRmDnsAvailability -DomainNameLabel "exflow$(((Get-AzureRmTenant).TenantId).Replace('-','').Substring(0,17))$($x)" -Location $Location)
        {
            $_TenantId = "exflow$(((Get-AzureRmTenant).TenantId).Replace('-','').Substring(0,17))$($x)"
            break
        }
    }
}
If (-not(Get-AzureRmResourceGroup -Name $_TenantId -Location $Location -ErrorAction SilentlyContinue) -and `
   (-not(Test-AzureRmDnsAvailability -DomainNameLabel $_TenantId -Location $Location)))
{
    Write-Warning "A unique AzureRm DNS name could not be automatically determined."
    Write-Warning "This script will be aborted."
    end
}
#endregion

#region Define parameters                           
$ResourceGroupName         = $_TenantId
                           
$StorageAccountName        = $_TenantId
$StorageContainer          = "artifacts"
$StorageType               = "Standard_LRS"
                           
$DeploymentName            = $_TenantId
                           
$WebApplicationName        = $_TenantId
$HomePage                  = "https://$($_TenantId).azurewebsites.net/inbox.aspx"
$IdentifierUris            = "https://$($_TenantId).azurewebsites.net"
                           
$FileName                  = "package.zip"                                       
$FilePath                  = $env:TEMP
                                     
$RedistPath                = "https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master"
$AzureSDKDllLocation       = $RedistPath
                           
$AzureSDKDlls              = @(
                              "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
                              "Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
                             )
                           
$requiredResourceAccess    = @{
    "resourceAppId"        = "00000015-0000-0000-c000-000000000000"
    "resourceAccess"       = @(
        @{                 
            "id"           = "6397893c-2260-496b-a41d-2f1f15b16ff3"
            "type"         = "Scope"
        },
        @{                 
            "id"           = "a849e696-ce45-464a-81de-e5c5b45519c1"
            "type"         = "Scope"
        },                 
        @{                 
            "id"           = "ad8b4a5c-eecd-431a-a46f-33c060012ae1"
            "type"         = "Scope"
        }                 
    )                         
}

$requiredResourceAccessAZ  = @{
    "resourceAppId"        = "00000002-0000-0000-c000-000000000000"
    "resourceAccess"       = @(
        @{                 
            "id"           = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
            "type"         = "Scope"
        }                
    )                         
}                         
                           
$CorsRules = @{            
    AllowedHeaders         = @("x-ms-meta-abc","x-ms-meta-data*","x-ms-meta-target*")
    AllowedOrigins         = @("https://$($_TenantId).azurewebsites.net")
    MaxAgeInSeconds        = 200
    ExposedHeaders         = @("x-ms-meta-*")
    AllowedMethods         = @("Get")
}

#jb $aad_TenantId              = (Get-AzureRmTenant).TenantId
$aad_ExternalApiId         = "https://$($DynamicsAXApiId)"
#endregion

#region Create AzureRmResourceGroup
If (-not($AzureRmResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue))
{

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmResourceGroup"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureRmResourceGroupParams = @{
        Name     = $ResourceGroupName
        Location = $Location
    }

    $AzureRmResourceGroup = New-AzureRmResourceGroup @AzureRmResourceGroupParams

    $x = 0
    While ((-not(Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue)) -and ($X -lt 10))
    {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmResourceGroup status for $(5*$x) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    Write-Output $AzureRmResourceGroup

}
#endregion

#region Create/Get AzureRmStorageAccount
If ($AzureRmResourceGroup -and -not (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue))
{

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmStorageAccount"
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "(This can take a while)"
    $AzureRmStorageAccountParams = @{
        Name              = $StorageAccountName
        ResourceGroupName = $ResourceGroupName
        Type              = $StorageType
        Location          = $Location
    }

    $AzureRmStorageAccount = New-AzureRmStorageAccount @AzureRmStorageAccountParams

    Write-Output $AzureRmStorageAccount

    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $Keys[0].Value
}
Else
{
    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName $Keys[0].Value
}
#endregion

#region Create AzureStorageContainer
If ($AzureRmResourceGroup -and -not(Get-AzureStorageContainer -Name $StorageContainer -Context $StorageContext -ErrorAction SilentlyContinue))
{

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureStorageContainer"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureStorageContainerParams = @{
        Name       = $StorageContainer
        Permission = "Off"
        Context    = $StorageContext
    }

    New-AzureStorageContainer @AzureStorageContainerParams

}
#endregion

#region Create AzureStorageCORSRule
$cRules = Get-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext

$cUpdate = $False
ForEach ($CorsRule in $CorsRules.Keys)
{
    If (!([string]$cRules.$CorsRule -eq [string]$CorsRules.$CorsRule))
    {
        $cUpdate = $True
        Break
    }
}

If ($cUpdate)
{

    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Create AzureStorageCORSRule"
    Write-Output "--------------------------------------------------------------------------------"

    Set-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext -CorsRules $CorsRules

    Get-AzureStorageCORSRule -ServiceType Blob -Context $StorageContext
}
#endregion

#region Create AzureRmADApplication
If (-not($AzureRmADApplication = Get-AzureRmADApplication -DisplayNameStartWith $WebApplicationName -ErrorAction SilentlyContinue))
{

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    $psadCredential           = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADPasswordCredential
    $startDate                = Get-Date
    $psadCredential.StartDate = $startDate
    $psadCredential.EndDate   = $startDate.AddYears(1)
    $psadCredential.KeyId     = [guid]::NewGuid()
    $psadKeyValue             = Create-AesKey
    $psadCredential.Password  = $psadKeyValue

    $SecurePassword = $psadKeyValue | ConvertTo-SecureString -AsPlainText -Force
    $SecurePassword | Export-Clixml "$env:USERPROFILE\PSDAKey.xml"

    Write-Output $psadCredential

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmADApplication"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureRmADApplicationParams = @{
        DisplayName         = $WebApplicationName
        HomePage            = $HomePage
        IdentifierUris      = $IdentifierUris
        ReplyUrls           = $HomePage
        PasswordCredentials = $psadCredential
    }

    $AzureRmADApplication = New-AzureRmADApplication @AzureRmADApplicationParams

    Write-Output $AzureRmADApplication
}
Else
{
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Importing PSADCredential"
    Write-Output "--------------------------------------------------------------------------------"

    If (!(Test-Path -Path "$($env:USERPROFILE)\PSDAKey.csv" -ErrorAction SilentlyContinue))
    {

        $SecurePassword = Import-Clixml "$env:USERPROFILE\PSDAKey.xml"
        $psadKeyValue  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))

        Write-Output $psadKeyValue
    }
    Else
    {
        Write-Warning "A PSADCredential could not be found, aborting"
        exit
    }
}
#endregion

#region Create AzureRmADServicePrincipal
If (-not($AzureRmADServicePrincipal = Get-AzureRmADServicePrincipal -SearchString $AzureRmADApplication.DisplayName -ErrorAction SilentlyContinue))
{

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmADServicePrincipal"
    Write-Output "--------------------------------------------------------------------------------"

    $AzureRmADServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $AzureRmADApplication.ApplicationId

    $x = 0
    While ($X -lt 6)
    {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmADServicePrincipal completion for $(30-(5*$x)) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    $x = 0
    While ((-not($AzureRmADServicePrincipal = Get-AzureRmADServicePrincipal -SearchString $AzureRmADApplication.DisplayName -ErrorAction SilentlyContinue)) -and ($X -lt 10))
    {
        Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmADServicePrincipal status for $(5*$x) seconds" -ForegroundColor "cyan"
        Start-Sleep 5
        $x++
    }

    Write-Output $AzureRmADServicePrincipal
}
#endregion

#region Create AzureRmRoleAssignment
If (-not($AzureRmRoleAssignment = Get-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ErrorAction SilentlyContinue))
{

    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Creating AzureRmRoleAssignment"
    Write-Output "--------------------------------------------------------------------------------"

    $x = 0
    While ((-not($AzureRmRoleAssignment)) -and ($X -lt 15))
    {
        $AzureRmRoleAssignment = $null
        Try
        {
            $AzureRmRoleAssignment = New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $AzureRmADApplication.ApplicationId -ErrorAction Stop
        }
        Catch
        {
            Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmRoleAssignment status for 5 seconds" -ForegroundColor "cyan"
            Start-Sleep 5
            $x++
        }
    }

    Write-Output $AzureRmADServicePrincipal
}
#endregion

#region Deploy Azure Resource Manager Template
Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Deploying Azure Resource Manager Template"
Write-Output "--------------------------------------------------------------------------------"

$TemplateParameters = @{
    Name                          = $DeploymentName
    ResourceGroupName             = $AzureRmResourceGroup.ResourceGroupName
    TemplateFile                  = "$($RedistPath)/WebSite.json"
    webApplicationPackageFolder   = $packageFolder #jb
    WebApplicationPackageFileName = $packageSAS #jb
    WebSiteName                   = $WebApplicationName
    StorageAccountName            = $StorageAccountName
    hostingPlanName               = $WebApplicationName
    aad_ClientId                  = $AzureRmADApplication.ApplicationId
    aad_ClientSecret              = $psadKeyValue
    aad_TenantId                  = $aad_TenantId
    aad_PostLogoutRedirectUri     = "$($IdentifierUris)/close.aspx?signedout=yes"
    aad_ExternalApiId             = $aad_ExternalApiId
    StorageConnection             = "DefaultEndpointsProtocol=https;AccountName=$($StorageAccountName);AccountKey=$($Keys[0].Value);"
    KeyValueStorageConnection     = "DefaultEndpointsProtocol=https;AccountName=$($StorageAccountName);AccountKey=$($Keys[0].Value);"
}

If ($Security_Admins)
{
    $TemplateParameters.Add("Security_Admins",$Security_Admins)
}

New-AzureRmResourceGroupDeployment @TemplateParameters -Verbose

$x = 0
While ($X -lt 3)
{
    Write-Host "SLEEP: $((Get-Date).ToString("hh:mm:ss")) - Awaiting AzureRmResourceGroupDeployment for $(15-(5*$x)) seconds" -ForegroundColor "cyan"
    Start-Sleep 5
    $x++
}
#endregion

#region Web App registration with Microsoft Graph REST Api
$WebClient = New-Object System.Net.WebClient
$SDKHeader = $True
ForEach ($DllFile in $AzureSDKDlls)
{
    If (!(Test-Path -Path "$($FilePath)\$($DllFile)" -ErrorAction SilentlyContinue))
    {
        If ($SDKHeader)
        {
            Write-Output ""
            Write-Output "--------------------------------------------------------------------------------"
            Write-Output "Downloading Azure SDK DLL:s"
            Write-Output "--------------------------------------------------------------------------------"
            $SDKHeader = $False
        }
        Write-Output "Downloading: $($DllFile)"
        $WebClient.DownloadFile("$($RedistPath)\$($DllFile)?raw=true", "$($FilePath)\$($DllFile)")
    }
}

$newGuid = [guid]::NewGuid()
$guidToBytes = [System.Text.Encoding]::UTF8.GetBytes($newGuid)

$mySecret = @{
    "type"      = "Symmetric"
    "usage"     = "Verify"
    "endDate"   = [DateTime]::UtcNow.AddDays(365).ToString("u").Replace(" ", "T")
    "keyId"     = $newGuid
    "startDate" = [DateTime]::UtcNow.AddDays(-1).ToString("u").Replace(" ", "T")
    "value"     = [System.Convert]::ToBase64String($guidToBytes)
}

$restPayload = @{
    "keyCredentials" = @($mySecret)
}

$restPayload.Add("requiredResourceAccess",@($requiredResourceAccess,$requiredResourceAccessAZ))

$restPayload = ConvertTo-Json -InputObject $restPayload -Depth 4

$token = GetAuthorizationToken -TenantName $tenantName

$authorizationHeader = @{
    "Content-Type"  = "application/json"
    "Authorization" = $token.CreateAuthorizationHeader()
}

$restUri = "https://graph.windows.net/$($tenantName)/applications/$($AzureRmADApplication.ObjectId)?api-version=1.6"

$restResourceAccess = Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Method GET | Select -ExpandProperty requiredResourceAccess

If ($restResourceAccess.resourceAppId -notcontains $requiredResourceAccess.resourceAppId)
{
    Write-Output ""
    Write-Output "--------------------------------------------------------------------------------"
    Write-Output "Configure application settings"
    Write-Output "--------------------------------------------------------------------------------"

    Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Body $restPayload -Method PATCH -Verbose
}
Else
{
    ForEach ($Resource in $restResourceAccess)
    {
        If ($resourceAccess.resourceAppId -eq $requiredResourceAccess.resourceAppId)
        {
            $resourceAccess = ($Resource | Select -ExpandProperty resourceAccess).id

            $updateResourceAccess = $False
            ForEach ($id in $requiredResourceAccess.resourceAccess.id)
            {
                If ($resourceAccess -notcontains $id)
                {
                    $updateResourceAccess = $True
                    Break
                }
            }

            If ($updateResourceAccess)
            {
                Write-Output ""
                Write-Output "--------------------------------------------------------------------------------"
                Write-Output "Configure application settings"
                Write-Output "--------------------------------------------------------------------------------"

                Invoke-RestMethod -Uri $restUri -Headers $authorizationHeader -Body $restPayload -Method PATCH -Verbose
            }
        }
    }
}

Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Cleaning up Azure SDK DLL:s"
Write-Output "--------------------------------------------------------------------------------"

ForEach ($DllFile in $AzureSDKDlls)
{
    Write-Output "Removing: $($DllFile)"
    Remove-Item -Path "$($FilePath)\$($DllFile)" -Force -ErrorAction SilentlyContinue
}
#endregion

$Measure.Stop()

Write-Output ""
Write-Output ""
Write-Output "Browse to the following URL to initialize the application:"
Write-Host $HomePage -ForegroundColor Green

Write-Output ""
Write-Output "--------------------------------------------------------------------------------"
Write-Output "Completed in $(($Measure.Elapsed).TotalSeconds) seconds"