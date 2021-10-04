@{

    Prefix                          = "exflow"
    AzureRmDomain                   = "azurewebsites.net"
    PowerShellVersion               = "5.0.0"
    AzCli                           = "2.0.80"
                                    
    RedistPath                      = ""
    PackageURL                      = "https://exflowpackagemanager.azurewebsites.net/"
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
            Name                    = "Az.Accounts"
            MinimumVersion          = "1.5.2"
        },
        @{                          
            Name                    = "Az.Websites"
            MinimumVersion          = "1.2.1"
        },
        @{                          
            Name                    = "Az.Network"
            MinimumVersion          = "1.8.0"
        },
        @{                          
            Name                    = "Az.Storage"
            MinimumVersion          = "1.3.0"
        },
        @{                          
            Name                    = "Az.Resources"
            MinimumVersion          = "1.3.1"
        }                            
    );                              
                                    
    Storage = @{                    
        Type                        = "Standard_LRS"
        Container                   = "artifacts"
    };                              
                                    
    PSADCredential = @{             
        Years                       = "10"
        ClixmlPath                  = "$($env:USERPROFILE)\PSDAKey.xml"
    }                               
                                    
    ApplicationRegistration = @{
        Type                        = "Symmetric"
        Days                        = "1825"
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
        "resourceAppId"               = "00000003-0000-0000-c000-000000000000"
        "resourceAccess"              = @(
            @{                        
                "id"                  = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
                "type"                = "Scope"
            }                         
        )                                  
    }                                 
                                      
    CorsRules = @{                     
        AllowedHeaders                = @("x-ms-meta-abc","x-ms-meta-data*","x-ms-meta-target*")
        AllowedOrigins                = @("https://[DeploymentName].azurewebsites.net")
        MaxAgeInSeconds               = 200
        ExposedHeaders                = @("x-ms-meta-*")
        AllowedMethods                = @("Get")
    }
}
