$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "EGMAGRA,KEFOL,MBRAN,KIJNI" #AX user name (UPPERCASE) of ExFlow web administrators. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "coro-uat.sandbox.operations.dynamics.com/" #URL such as axtestdynamics365aos.cloudax.dynamics.com
$ExFlowUserSecret          = "1a73f90b52c44c70a892987cb526d263" #Your identity recieved by signupsoftware.com
$Prefix                    = "" #Optional prefix (short using alphanumeric characters). Leave blank for default behavior.
$PackageVersion            = "" #Optional version to install.  Leave blank for default behavior.
$TenantGuid                = "2d9c7aaa-2448-49d8-ad14-9044694cbaaf" #Optional tenant id when you have multiple tenants (advanced).   
$WebAppSubscriptionGuid    = "4bb56e2f-3830-4c3f-9bd5-8578403dd03c" #Optional Subscription for the web app (advanced). Use if you have two subscriptions, one holding tenant (AD) and another for apps. You will be prompted twice for cretedials, (1) use AD admin credentials, (2) the subscription co-admin for the second subscription.       
$TenantnameSpecific        = "corocorp.onmicrosoft.com" #Specify the Azure AD tenant name.
#$ReplacePattern            = #This pattern is used, to convert the $DynamicsAXApiId in to useable format for a Storage accounts container. If blank, default is '[^a-zA-Z0-9]' 

#$scriptPath = ((New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/App-RegistrationDeployment.ps1'))
$scriptPath = 'C:\Users\magra\Google Drive\Arbejde\CORO\D365O\ExFlow installation\exflowwebd365o-master\App-RegistrationDeployment.ps1'
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$ExFlowUserSecret,$Prefix,$PackageVersion,$TenantGuid,$WebAppSubscriptionGuid,$TenantnameSpecific,$ReplacePattern