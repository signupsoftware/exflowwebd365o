Function Get-ConfigurationDataAsObject
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
        [hashtable] $ConfigurationData    
    )

    return $ConfigurationData
}

Function Get-RequiredModules
{
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        $Modules
    )

    [bool]$hasErrors = $False

    ForEach ($Module in $Modules)
    {
        $cModule = Get-Module -ListAvailable -Name $Module.Name | Sort-Object -Descending | Select -First 1
        If (!$cModule) {
            Write-Warning "Module $($Module.Name) is not installed."
            Write-Warning "`tInstall-Module -Name $($Module.Name)"
            Try { Invoke-Logger -Message "Module $($Module.Name) is not installed" -Severity W -Category "PSModule" } Catch {}
            $hasErrors = $True
        } Else {
            If ($cModule.Version -lt $Module.MinimumVersion) {
                Write-Warning "Module $($Module.Name) must be updated."
                Write-Warning "`tInstall-Module -Name $($Module.Name) -AllowClobber -Force"
                Try { Invoke-Logger -Message "Module $($Module.Name) must be updated" -Severity W -Category "PSModule" } Catch {}
                $hasErrors = $True
            } Else {
                Write-Host "Module $($Module.Name) version $($cModule.Version) is valid."
                Try { Invoke-Logger -Message "Module $($Module.Name) version $($cModule.Version) is valid" -Severity I -Category "PSModule" } Catch {}
            }
        }
    }

    Return $hasErrors
}

Function Set-AzureRmLogon
{
    param(
        [Parameter(Mandatory=$False)]
        $SubscriptionGuid
    )

    $AzureRmLogon = $null

    If ($SubscriptionGuid) {
        $AzureRmLogon = Login-AzureRmAccount -SubscriptionId $SubscriptionGuid
    } Else{
        $AzureRmLogon = Login-AzureRmAccount
    }

    Return $AzureRmLogon
}

Function Get-ChoiceMenu
{
    param(
        [Parameter(Mandatory=$False)]
        $SubscriptionGuid,

        $mChoices,
        $Choices

    )

    $caption = "Multiple subscriptions"
    $message = "Please select appropriate subscription"

    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($mChoices)
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    Return $answer
}

Function Set-DeploymentName
{
    param(
        [Parameter(Mandatory=$True)]
        [string]$String,

        [Parameter(Mandatory=$False)]
        [string]$Prefix
    )

    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($String)))

    If ($prefix){ $hash = $prefix+$hash }

    If (($ConfigurationData.AzureRm.Prefix).Length -lt 24) {
        $DeploymentName = "$($ConfigurationData.Prefix)$(($hash.ToLower()).Replace('-','').Substring(0,(24 - ($ConfigurationData.Prefix).Length)))"
    } Else {
        $DeploymentName = ($ConfigurationData.Prefix).Substring(0,24)
    }

    If (-not(Get-AzureRmResourceGroup -Name $DeploymentName -Location $Location -ErrorAction SilentlyContinue) -and `
       (-not(Test-AzureRmDnsAvailability -DomainNameLabel $DeploymentName -Location $Location)))
    {
        For ($x=1; $x -le 9; $x++)
        {
            If (Test-AzureRmDnsAvailability -DomainNameLabel "$($ConfigurationData.Prefix)$(((Get-AzureRmTenant).TenantId).Replace('-','').Substring(0,17))$($x)" -Location $Location)
            {
                $DeploymentName = "$($ConfigurationData.Prefix)$(((Get-AzureRmTenant).TenantId).Replace('-','').Substring(0,17))$($x)"
                break
            }
        }
    }

    Return $DeploymentName
}

Function Publish-FileToBlob
{
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$File,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$StorageAccountName
    )

    $sasToken          = $StorageContext | New-AzureStorageContainerSASToken -Container $ConfigurationData.Storage.Container -Permission rwdl
    $newStorageContext = New-AzureStorageContext -SasToken $sasToken -StorageAccountName $StorageAccountName
    $null              = $newStorageContext | Set-AzureStorageBlobContent -File $File -Container $ConfigurationData.Storage.Container -Force

    Return $sasToken

}

Function Get-TruncatedStringHash
{ 
    Param
    (
        [ValidateNotNullOrEmpty()]
        [String]$String,

        [ValidateNotNullOrEmpty()]
        [String]
        $HashName = "SHA512",

        [ValidateNotNullOrEmpty()]
        [int]
        $Length = 21
    )
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{ 
        [Void]$StringBuilder.Append($_.ToString("x2"))
    } 
    $StringBuilder.ToString().Substring(0,$Length)
}

Function Get-WebDownload
{
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Source,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [string]$Target
    )

    If (Get-Service BITS | Where-Object {$_.status -eq "running"})
    {
        Import-Module BitsTransfer -Verbose:$false
        Start-BitsTransfer -Source $Source -Destination $Target
        Remove-Module BitsTransfer -Verbose:$false
    }
    else
    {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Source, $Target)
    }
}

#Function to get authorization token for communication with the Microsoft Graph REST API
Function Get-AuthorizationToken
{
    param
    (
            [Parameter(Mandatory=$true)]
            $TenantName
    )

    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------"
    Write-Host "Logging in to Microsoft Graph API"
    Write-Host "--------------------------------------------------------------------------------"

    $adal             = "${ConfigurationData.LocalPath}\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms        = "${ConfigurationData.LocalPath}\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId         = "1950a258-227b-4e31-a9cf-717495945fc2"
    $redirectUri      = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://$($ConfigurationData.GraphAPI.URL)"
    $authority        = "https://login.windows.net/$TenantName"
    $authContext      = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $authResult       = $authContext.AcquireToken($resourceAppIdURI, $clientId,$redirectUri, "Auto")

    return $authResult
}

#Function to create AesManagedObject for the PSADCredential
Function Set-AesManagedObject($key, $IV) {
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
Function Set-AesKey() {
    $aesManaged = Set-AesManagedObject 
    $aesManaged.GenerateKey()
    [System.Convert]::ToBase64String($aesManaged.Key)
}

Function Get-RecursiveHashTable {
    param
    (
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Category
    )
    $date = [datetime]::UtcNow
    ForEach ($prop in $Object.Keys)
    {
        If ($prop) {
            If (($($Object.$prop).GetType()).Name -eq "Hashtable") {
                Get-RecursiveHashTable -Object ($Object.$prop) -Category $Category
            }
            Else {
                If (($prop -eq "aad_ClientSecret") -or ($prop -eq "Password") -or ($prop -eq "StorageConnection") -or ($prop -eq "KeyValueStorageConnection") -or ($prop -eq "ConnectionString")) {
                    Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [INFO] [$($Category)] [$($prop): *****]"
                }
                Else {
                    Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [INFO] [$($Category)] [$($prop): $($Object.$prop)]"
                }
            }
        }
    }
}

Function Get-RecursivePSObject {
    param
    (
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Category
    )
    $date = [datetime]::UtcNow
    ForEach ($prop in $Message.PSObject.Properties)
    {
        If ($prop.Value) {
            If ($prop.Value -is [PSObject])
            {
                Get-RecursivePSObject -Object ($prop.Value) -Category $Category
            }
            Else
            {
                If (($prop.Name -eq "aad_ClientSecret") -or ($prop.Name -eq "Password") -or ($prop.Name -eq "StorageConnection") -or ($prop.Name -eq "KeyValueStorageConnection") -or ($prop.Name -eq "ConnectionString")) {
                    Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($prop.Name): *****]"
                }
                Else {
                    Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($prop.Name): $($prop.Value)]"
                }
            }
        }
    }
}

Function Invoke-Logger
{
    param(
        [String]$Severity,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        [String]$Category,

        $Message,

        $Error
    )

    Switch ($Severity) 
    { 
        "I"     { $Severity = "INFO" }
        "D"     { $Severity = "DEBUG" }
        "W"     { $Severity = "WARNING" }
        "E"     { $Severity = "ERROR"}
        default { $Severity = "INFO" }
    }

    $date = [datetime]::UtcNow

    If ($Error)
    {
        ForEach ($Line in $Message)
        {
            Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($Line)]"
        }
        If ($Error.Exception.Message) { Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($Error.Exception.Message)]" }
        If ($Error.Exception.Innerexception) { Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($Error.Exception.Innerexception)]" }
        If ($Error.InvocationInfo.PositionMessage) {
            ForEach ($Line in $Error.InvocationInfo.PositionMessage.Split("`n"))
            {
                Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($Line)]"
            }
        }
    }
    Else
    {
        If ($Message)
        {
            If (($Message.GetType()).Name -eq "Hashtable")
            {
                Get-RecursiveHashTable -Object $Message -Category $Category
            }
            ElseIf ($Message -is [PSObject])
            {
                Get-RecursivePSObject -Object $Message -Category $Category
            }
            Else
            {
                ForEach ($Line in $Message)
                {
                    If ($Line) {
                        Write-Log -Message "[$(Get-Date $date -UFormat '%Y-%m-%dT%T%Z')] [$($Severity)] [$($Category)] [$($Line)]"
                    }
                }
            }
        }
    }

}

Function Write-Log
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullorEmpty()]
        $Message
    )
    Out-File -FilePath $LogFile -InputObject $Message -Encoding utf8 -Append -NoClobber
}