
# Bulk Invite Guest Users to Azure Entra ID (Azure AD) via Microsoft Graph

## 📌 Overview

This PowerShell script allows administrators to **bulk invite guest users** to an **Azure Entra ID (formerly Azure Active Directory)** tenant using **Microsoft Graph**. It includes retry logic for connecting to Microsoft Graph, supports both **interactive** and **device code login**, and reads user details from a CSV file.

## ✨ Features

- Connects to Microsoft Graph securely using MS Graph PowerShell SDK
- Retry logic with customizable attempt count
- Supports both interactive and device-based authentication
- Invites guest users based on a CSV file input
- Allows optional CC recipients in the invitation email (limited to one due to API constraints)
- Includes meaningful console output and error handling

---

## 📁 Prerequisites

- PowerShell 5.1+ or PowerShell Core 7+
- [Microsoft.Graph PowerShell module](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)
- Azure Entra ID Tenant ID
- A CSV file with guest user details

---

## 📄 CSV File Format

Create a file named `BulkInviteGuestUsersToAzureEntraID.csv` in the same folder as the script with the following columns:

```csv
emailAddress,displayName,ccRecipients
guest1@example.com,Guest One,manager1@example.com
guest2@example.com,Guest Two,
```

> **Note:** Only the first `ccRecipient` will be used due to a known Microsoft Graph API limitation.

---

## 🔧 Script Configuration

Open the script and configure the following variables:

```powershell
$Scopes = "User.Invite.All" # Required scope
$csvFilePath = ".\BulkInviteGuestUsersToAzureEntraID.csv"
$TenantID = "<your-tenant-id-guid-here>" # Replace with your tenant ID
$emailAddresses = $Null # Optional static list of CC recipients
```

---

## ▶️ How to Run

1. Open PowerShell as Administrator
2. Install Microsoft Graph module (if not already):

   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

3. Execute the script:

   ```powershell
   .\InviteGuestsToAzureEntraID.ps1
   ```

   Or specify login type:

   ```powershell
   Test-GraphConnection -TenantID "<tenant-id>" -Scopes $Scopes -UseDeviceLogin
   ```

---

## 🧠 Function: `Test-GraphConnection`

This helper function ensures a valid Microsoft Graph session is established:

- Disconnects any stale Graph sessions
- Attempts up to `$MaxRetries` times to connect
- Verifies that the session is for the specified Tenant ID
- Supports `-UseDeviceLogin` switch for non-interactive login (e.g., headless servers)

---

## 📬 Inviting Users

The script loops through all entries in the CSV file and sends out personalized invitations using the `New-MgInvitation` cmdlet.

Each invite includes:

- Redirect URL (`https://mycompany.portal.com`)
- Display name from CSV
- Custom message
- Optional CC recipient (only first address is respected by Graph API)

---

## ⚠️ Known Issues

- **CC Recipients Limitation**: Only the first email in `ccRecipients` is honored. This is a [known issue in the Microsoft Graph API](https://learn.microsoft.com/en-us/graph/api/invitation-post?view=graph-rest-1.0).
- **Multi-user CC**: If different users need unique CCs, adapt the script to parse a `ccRecipients` column with user-specific values.

---

## 📤 Example Output

```
✅ Using device login for Microsoft Graph...
✅ Microsoft Graph is connected to the correct Azure tenant (xxxx-xxxx-xxxx).
✅ Invitation sent to Guest One using guest1@example.com
⚠️  Skipped a user due to missing email address.
⚠️  Failed to invite Guest Two: Insufficient privileges to complete the operation
```

---

## 🧽 Cleanup / Disconnect

Graph sessions are managed per execution. If needed, manually disconnect with:

```powershell
Disconnect-MgGraph
```

---

## 📚 References

- [Microsoft Graph PowerShell Docs](https://learn.microsoft.com/en-us/powershell/microsoftgraph/)
- [Microsoft Graph Invitation API](https://learn.microsoft.com/en-us/graph/api/invitation-post)

---

## 🛡️ License

This script is provided as-is without warranty. Use it at your own risk. Feel free to adapt and extend as needed.

---

## ✍️ Author

Didier Van Hoye
Contributions welcome!
