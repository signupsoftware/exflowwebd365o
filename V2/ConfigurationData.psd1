@{

    Prefix                          = "exflow"
    AzureRmDomain                   = "azurewebsites.net"
    PowerShellVersion               = "5.0.0"
                                    
    RedistPath                      = "https://github.com/djpericsson/AzureWebAppDeploy/raw/master"
    PackageURL                      = "https://exflowpackagemanager.azurewebsites.net"
    LocalPath                       = $env:TEMP

    LogFile                         = "App-RegistrationDeployment.log"
                                    
    WebApplication                  = "package.zip"

    AzureRmRoleAssignmentValidation = $True

    GraphAPI = @{
        URL                         = "graph.windows.net"
        Version                     = "1.6"
    }                               
                                    
    Modules = @(                    
        @{                          
            Name                    = "AzureRM"
            MinimumVersion          = "4.0.2"
        }                           
    );                              
                                    
    Storage = @{                    
        Type                        = "Standard_LRS"
        Container                   = "artifacts"
    };                              
                                    
    PSADCredential = @{             
        Years                       = "1"
        ClixmlPath                  = "$($env:USERPROFILE)\PSDAKey.xml"
    }                               
                                    
    ApplicationRegistration = @{
        Type                        = "Symmetric"
        Days                        = "365"
    }                               
                                    
    AzureSDK = @{                   
        Dlls                        = @(
                                      "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
                                      "Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
                                      )
    }

    RequiredResourceAccess = @{
        "resourceAppId"               = "00000015-0000-0000-c000-000000000000"
        "resourceAccess"              = @(
            @{                        
                "id"                  = "6397893c-2260-496b-a41d-2f1f15b16ff3"
                "type"                = "Scope"
            },                        
            @{                        
                "id"                  = "a849e696-ce45-464a-81de-e5c5b45519c1"
                "type"                = "Scope"
            },                        
            @{                        
                "id"                  = "ad8b4a5c-eecd-431a-a46f-33c060012ae1"
                "type"                = "Scope"
            }                          
        )                                  
    }                                 
                                      
    RequiredResourceAccessAZ          = @{
        "resourceAppId"               = "00000002-0000-0000-c000-000000000000"
        "resourceAccess"              = @(
            @{                        
                "id"                  = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
                "type"                = "Scope"
            }                         
        )                                  
    }                                 
                                      
    CorsRules = @{                     
        AllowedHeaders                = @("x-ms-meta-abc","x-ms-meta-data*","x-ms-meta-target*")
        AllowedOrigins                = @("https://[TenantId].azurewebsites.net")
        MaxAgeInSeconds               = 200
        ExposedHeaders                = @("x-ms-meta-*")
        AllowedMethods                = @("Get")
    }
}