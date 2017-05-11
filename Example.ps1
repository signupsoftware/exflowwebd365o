$Location                  = "northeurope" #Azure location notheurope, westeurope,... 
$Security_Admins           = "JOHANB,JERRY" #AX user name (UPPERCASE) of ExFlow web administrators. Admins can translate texts, write welecome messages, ...
$DynamicsAXApiId           = "axtestdynamics365aos.cloudax.dynamics.com" #URL such as axtestdynamics365aos.cloudax.dynamics.com
$ExFlowUserSecret          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #Your identity recieved by signupsoftware.com

$scriptPath = ((New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/signupsoftware/exflowwebd365o/master/App-RegistrationDeployment.ps1'))
Invoke-Command -ScriptBlock ([scriptblock]::Create($scriptPath)) -ArgumentList $Location,$Security_Admins,$DynamicsAXApiId,$ExFlowUserSecret 
