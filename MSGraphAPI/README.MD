### Step 1
* Go to App Services and find your webapp > Go to "Configuration" in the WebApp Blade and view "Application Settings" > Copy the value of "aad_ClientId"
![Appservice](/newApiPermissions/AppPermissionMig1.png)
* Go to Azure Active Directory > App Registrations > All applications > paste the value of "aad_ClientId" 
![Appservice](/newApiPermissions/AppPermissionMig2.png)

# Manual Update:
### Step 2
* Go to "API Permissions" > "Add a permission" > "Microsoft Graph"
![Appservice](/newApiPermissions/AppPermissionMig3.png)
* Select "Delegated permissions" > Search for "user.read" > Select "User.Read" delegated permissions 
![Appservice](/newApiPermissions/AppPermissionMig4.png)
* Remove the old Azure Active Directory Graph permissions
![Appservice](/newApiPermissions/AppPermissionMig5.png)
* Grant Admin consent with the new permissions and remove the old one.

# Updating after re-running V3 script:
* ![Appservice](/newApiPermissions/AppPermissionMigV3.png)
