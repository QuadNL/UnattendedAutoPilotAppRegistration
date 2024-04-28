# UnattendedAutoPilotAppRegistration-
Easy deployment of Microsoft AutoPilot device registration with an app
<#
.SYNOPSIS
    This script creates a new Azure AD application (deletes if one exists), generates a client secret, and displays relevant details.
    It also generates a new script with the retrieved information so it can be used for automatic AutoPilot import.

.DESCRIPTION
    The script generates a new application password credential for an Azure AD application.
    You can specify the number of months until the credential expires using the -MonthsToExpire parameter.
    By default, the credential will expire in 6 months.
    With the retrieved information it creates a new PowerShell script in the same directory: AutomatedAutoPilotUploadTo_<yourtenantdisplayname>.ps1

.PARAMETER -MonthsToExpire
    Specifies the number of months until the credential expires.
    Default value is 6.

.PARAMETER -AppRegistrationName
    Specifies the name of the Azure AD application.
    Default value is "AutomatedAutoPilotUpload".

.NOTES
    Version: 1.0
    Author: Elbert Beverdam
    Date: 2024-04-28

.EXAMPLE
  .\UnattendedAutoPilotAppRegistration.ps1 -MonthsToExpire 3 -AppRegistrationName “MyApp” 
  Creates a new application password credential that expires in 3 months for an application named “MyApp”.

#>
