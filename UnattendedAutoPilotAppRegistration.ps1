<#
.SYNOPSIS
    This script creates a new Azure AD application (deletes if one exists), generates a client secret, and displays relevant details.
    It also generates a new script with the retrieved information so it can be used for automatic AutoPilot import.

.DESCRIPTION
    The script generates a new application password credential for an Azure AD application.
    You can specify the number of months until the credential expires using the -MonthsToExpire parameter.
    By default, the credential will expire in 6 months.
    With the retrieved information it creates a new PowerShell script in the same directory: UnattendedAutoPilotUploadTo_<yourtenantdisplayname>.ps1

.PARAMETER -MonthsToExpire
    Specifies the number of months until the credential expires.
    Default value is 6.

.PARAMETER -AppRegistrationName
    Specifies the name of the Azure AD application.
    Default value is "UnattendedAutoPilotUpload".

.NOTES
    Version: 1.0
    Author: Elbert Beverdam
    Date: 2024-04-28

.EXAMPLE
  .\UnattendedAutoPilotAppRegistration.ps1 -MonthsToExpire 3 -AppRegistrationName “MyApp” 
  Creates a new application password credential that expires in 3 months for an application named “MyApp”.

#>

param (
    [int]$MonthsToExpire = 6,
    [string]$AppRegistrationName = "UnattendedAutoPilotUpload"
)


$ErrorActionPreference = "Stop"

# Check if the AzureAD module is already installed
if (-not (Get-Module AzureAD -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Azure AD.."

    # Install the AzureAD module without confirmation
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module AzureAD -AllowClobber -Scope AllUsers -Force

    # Import the AzureAD module
    Import-Module AzureAD

    Write-Host "Azure AD is installed and imported."
} else {
    Write-Host "Azure AD is already installed."
}

# Connect to Azure AD using global admin credentials
Write-Host "Connecting to Azure AD.."
$null = Connect-AzureAD

# Retrieve the tenant ID and DisplayName using the Azure AD tenant context
$TenantId = (Get-AzureADTenantDetail).ObjectId
$TenantName = (Get-AzureADTenantDetail).DisplayName

Write-Host "Connected to $TenantName." -ForegroundColor Green

# Define variables
$GraphPermissions = "DeviceManagementServiceConfig.ReadWrite.All"
$ClientSecretName = "Autopilot Registration secret"

# Check if an UnattendedAutoPilotUpload Azure AD application exists
if ($AppRegistration = Get-AzureADApplication -Filter "DisplayName eq '$($AppRegistrationName)'" -ErrorAction SilentlyContinue) {
    # If it exists, delete the existing app registration
    Remove-AzureADApplication -ObjectId $AppRegistration.ObjectId
}


# Check if the Microsoft.Graph.Applications module is already installed
if (-not (Get-Module -ListAvailable Microsoft.Graph.Applications)) {
    Write-Host "Installing Microsoft.Graph.Applications.."

    # Install the Microsoft.Graph.Applications module without confirmation
    Install-Module Microsoft.Graph.Applications -AllowClobber -Scope AllUsers -Force

    # Import the Microsoft.Graph.Applications module
    Import-Module Microsoft.Graph.Applications

    Write-Host "Microsoft.Graph.Applications is installed and imported."
} else {
    Write-Host "Microsoft.Graph.Applications is already installed."
}


# Check if the Microsoft.Graph.Authentication module is already installed
if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
    Write-Host "Installing Microsoft.Graph.Authentication.."

    # Install the Microsoft.Graph.Authentication module without confirmation
    Install-Module Microsoft.Graph.Authentication -AllowClobber -Scope AllUsers -Force

    # Import the Microsoft.Graph.Authentication module
    Import-Module Microsoft.Graph.Authentication

    Write-Host "Microsoft.Graph.Authentication is installed and imported."
} else {
    Write-Host "Microsoft.Graph.Authentication is already installed."
}


Write-Host "Microsoft Graph is installed."
Write-Host "Connecting to Microsoft Graph.."

# Connect to Microsoft Graph
Connect-MgGraph -Scopes AppRoleAssignment.ReadWrite.All,Application.ReadWrite.All -NoWelcome

Write-Host "Connected to Microsoft Graph." -ForegroundColor Green

$requiredResourceAccess = (@{
  "resourceAccess" = (
    @{
      id = "06a5fe6d-c49d-46a7-b082-56b1b14103c7"
      type = "Role"
    },
    @{
      id = "5ac13192-7ace-4fcf-b828-1a26f28068ee"
      type = "Role"
    }
  )
  "resourceAppId" = "00000003-0000-0000-c000-000000000000"
})


# create the application
$app = New-MgApplication -DisplayName "$AppRegistrationName" -RequiredResourceAccess $requiredResourceAccess

# grant admin consent
$graphSpId = $(Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'").Id
$sp = New-MgServicePrincipal -AppId $app.appId
$null = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "06a5fe6d-c49d-46a7-b082-56b1b14103c7" -ResourceId $graphSpId
$null = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "5ac13192-7ace-4fcf-b828-1a26f28068ee" -ResourceId $graphSpId 

Write-Host "Please wait until app $AppRegistrationName is created.."  -ForegroundColor Yellow
Write-Host "This process may take up to 30 seconds. Please wait..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Write-Host "App $AppRegistrationName created!" -ForegroundColor Green

# Calculate the end date
$EndDate = (Get-Date).AddMonths($MonthsToExpire)

# Create a client secret
$ClientId = Get-AzureADApplication -Filter "DisplayName eq '$($AppRegistrationName)'"
$ObjectId = $app.Id
$ClientSecret = New-AzureADApplicationPasswordCredential -ObjectId $ObjectId -CustomKeyIdentifier $ClientSecretName -EndDate $EndDate
$AppId = $ClientId.AppId
$AppSecret = $ClientSecret.Value

# Display the app registration details
Write-Host ""
Write-Host "`$TenantId =   "-NoNewline
Write-Host "`"$($TenantId)`"" -ForegroundColor Green
Write-Host "`$AppId = " -NoNewline
Write-Host "`"$($ClientId.AppId)`"" -ForegroundColor Green
Write-Host "`$AppSecret = " -NoNewline
Write-Host "`"$($ClientSecret.Value)`"" -ForegroundColor Green
Write-Host "Appsecret $($AppRegistrationName) expires on $($EndDate)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Copying received content into new UnattendedAutoPilotUploadTo_$TenantName.ps1 script..." -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 5

# Clean up
$null = Disconnect-MgGraph
$null = Disconnect-AzureAD 


# Determine the current script's directory
$thisScriptDirectoryPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Create a new script in the same folder
$newScriptPath = Join-Path $thisScriptDirectoryPath "UnattendedAutoPilotUploadTo_$TenantName.ps1"

# Define the content of the new script
$newScriptContent = @"
<#
.SYNOPSIS
    This script uses an Azure AD application for Windows Autopilot unattended upload.

.DESCRIPTION
    The script sets up necessary environment settings and installs required components.
    It then runs the Get-WindowsAutopilotInfo script with unattended upload configuration.

.PARAMETER
    No additional paramaters needed.

.NOTES
    Version: 1.0
    Author: Elbert Beverdam
    Date: 2024-04-28

.EXAMPLE
    .\UnattendedAutoPilotUploadTo_<tenantname>.ps1
    Uses the Azure AD application for Windows Autopilot unattended upload.

#>

# Tenant variables
`$TenantId = "$TenantId"
`$AppId = "$AppId"
`$AppSecret = "$AppSecret"

# Environment variables
`$scriptPath = 'C:\Program Files\WindowsPowerShell\Scripts'
`$env:Path += ';`$scriptPath'

# Execution policy settings
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# PowerShell repository settings
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

# Install the NuGet provider (if not already installed)
Install-PackageProvider -Name NuGet -Confirm:`$false -Force

# Install the Get-WindowsAutopilotInfo script
Install-Script -Name Get-WindowsAutopilotInfo -Confirm:`$false -Force

# Unattended upload configuration
`$UnattendedUpload = @{
    Online = `$true
    TenantId = `$TenantId
    AppId = `$AppId
    AppSecret = `$AppSecret
}

# Run the Get-WindowsAutopilotInfo script with the unattended upload configuration
Write-Host ""
Write-Host "Importing and assigning device"
Write-Host "Please make sure you have automatic profile assignment configured in Intune!" -ForegroundColor Yellow
Write-Host ""

Get-WindowsAutopilotInfo.ps1 -assign @UnattendedUpload

# Uninstall the installed Get-WindowsAutopilotInfo script
Uninstall-Script -Name Get-WindowsAutopilotInfo

# Clean up
`$null = Disconnect-MgGraph
"@

# Write the content to the new script
$newScriptContent | Set-Content -Path $newScriptPath

Write-Host "New UnattendedAutoPilotUploadTo_$TenantDisplayName.ps1 script created at: $newScriptPath" -ForegroundColor Yellow