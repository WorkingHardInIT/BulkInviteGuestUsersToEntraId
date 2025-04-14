function Test-GraphConnection {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantID,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Scopes,

        [switch]$UseDeviceLogin,

        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3
    )

    $attempt = 0

    # Function to attempt to connect to Graph
    function Invoke-GraphConnect {
        param (
            [string]$TenantID,
            [string[]]$Scopes,
            [switch]$UseDeviceLogin
        )

        try {
            # Clear any existing session context
            Disconnect-MgGraph -ErrorAction SilentlyContinue

            # Connect to Microsoft Graph
            if ($UseDeviceLogin) {
                Write-Host "🔑 Using device login for Microsoft Graph..." -ForegroundColor Cyan
                $connectParams = @{ TenantId = $TenantID; Scopes = $Scopes; UseDeviceCode = $true; ErrorAction = 'Stop' }
            }
            else {
                Write-Host "🔑 Using interactive login for Microsoft Graph..." -ForegroundColor Cyan
                $connectParams = @{ TenantId = $TenantID; Scopes = $Scopes; ErrorAction = 'Stop' }
            }

            Connect-MgGraph @connectParams | Out-Host

            # Get the context after connecting
            Start-Sleep -Seconds 1 # Give some time for the connection to establ
            $newContext = Get-MgContext

            if ($newContext -and $newContext.TenantId -eq $TenantID) {
                Write-Host "✅ Microsoft Graph is connected to the correct Azure tenant ($TenantID)." -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "⚠️ Still not connected or connected to wrong tenant ($($newContext.TenantId))." -ForegroundColor Yellow
                return $false
            }
        }
        catch {
            Write-Host "❌ Connection attempt failed: $_" -ForegroundColor Red
            return $false
        }
    }

    # Initial check before any retries
    $initialContext = Get-MgContext 
    if ($initialContext -and $initialContext.TenantId -eq $TenantID) {
        Write-Host "✅ Microsoft Graph is already connected to the correct Azure tenant ($TenantID)." -ForegroundColor Green
        return
    }

    # Retry logic if the connection isn't established
    while ($attempt -lt $MaxRetries) {
        Write-Host "⏳ Attempting to connect to Microsoft Graph (tenant $TenantID), attempt $($attempt + 1) of $MaxRetries..." -ForegroundColor Cyan

        if (Invoke-GraphConnect -TenantID $TenantID -Scopes $Scopes -UseDeviceLogin:$UseDeviceLogin) {
            return  # Exit if successful
        }

        $attempt++
        Start-Sleep -Seconds 2  # Add a delay between retries
    }

    Write-Host "❗ Failed to connect to Microsoft Graph after $MaxRetries attempt(s)." -ForegroundColor DarkRed
    throw "Unable to connect to Microsoft Graph with tenant ID: $TenantID. Please check your network connection, tenant ID, and permissions for the provided scopes."
}

$Scopes = "User.Invite.All" #These are the minimal permissions needed to invite guest users.

# Set working directory to script location
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
Set-Location -Path $scriptDir

# Now you can use relative paths safely
Write-Host "✅ Working directory set to: $(Get-Location)"

$csvFilePath = ".\BulkInviteGuestUsersToAzureEntraID.csv" #Path to the CSV file containing user email addresses and display names

# Your Azure Entra ID tenant ID to which you invite guest users
# ccRecipients has had many bugs. It still has. ccRecipients are people you want to be CCed in the invitation email. The direct report
# of the invitees and your manager for example. However, multiple ccRecipients don't work, the CSV and code handle it but the API doesn't.
# It will only mail the first ccRecipient. This is a known issue with the API and I hope Microsoft is working on it.
# Note that you might have a different report for different invitees, in that case an extra column in the CSV file would be needed
# to specify the CCed people for each invitee and this script adapted to handle this. Comment out the code block below is that is the case.
# $emailAddresses = @("InviteeBoss@thiscorp.com", "YourBoss@that corp.com")
$emailAddresses = $Null

do {
    $tenantId = $(Write-host -ForegroundColor green "❓ Enter your Azure Tenant ID (GUID format): " -NoNewline; Read-Host).Trim()
    Write-Host -ForegroundColor green "👉 The provided Tenant ID is: $tenantId"
} while (-not $tenantId -or -not ($tenantId -match '^[0-9a-fA-F\-]{36}$'))
#Test-GraphConnection -TenantID $TenantID -Scopes $Scopes #To leverage user login
Test-GraphConnection -TenantID $TenantID -Scopes $Scopes -UseDeviceLogin #To leverage  device login

if (-Not (Test-Path -Path $csvFilePath)) {
    throw "CSV file not found at the specified path."
}

$users = Import-Csv -Path $csvFilePath

if (-Not $users -or -Not $users[0].PSObject.Properties.Match('emailAddress')) {
    throw "CSV file is empty or missing the 'emailAddress' column."
}

# Loop through users and send invitations
foreach ($user in $users) {

    if ($Null -eq $emailAddresses) {
        $emailAddresses = $user.ccRecipients -split ';'
        $ccRecipients = @()
        foreach ($email in $emailAddresses) {
            $ccRecipients += @{
                emailAddress = @{
                    address = $email
                }
            }
        }
    }

    try {
        if (![string]::IsNullOrWhiteSpace($user.emailAddress)) {
            $inviteParams = @{
                InvitedUserEmailAddress = $user.emailAddress
                InviteRedirectUrl       = "https://mycompany.portal.com"
                SendInvitationMessage   = $true
                InvitedUserDisplayName  = $user.displayName
                InvitedUserMessageInfo  = @{
                    CustomizedMessageBody = "Hello $($user.displayName), welcome to your Azure Entra ID tenant!"
                    ccRecipients          = $ccRecipients
                }
            }

            New-MgInvitation @inviteParams | Format-Table * -AutoSize -ErrorAction Stop
            Write-Host "✅ Invitation sent to $($user.displayName) using $($user.emailAddress)" -ForegroundColor Green
        }
        else {
            Write-Warning "⚠️  Skipped a user due to missing email address."
        }
    }
    catch {
        Write-Warning "⚠️  Failed to invite $($user.displayName) using $($user.emailAddress): $($_.Exception.Message)"
    }
}
