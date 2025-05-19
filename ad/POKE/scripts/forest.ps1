<#
.SYNOPSIS
Finds user 'cynthia' in 'sinnoh.pokemon.local' and adds them to the 
'Enterprise Admins' group, targeting DC 'dc04.pokemon.local' for the addition.

.DESCRIPTION
This script first attempts to locate the user object for 'cynthia' within the 
'sinnoh.pokemon.local' domain, optionally querying a specific child domain DC. 
If the user is found, it then connects specifically to 'dc04.pokemon.local' 
(parent domain DC) to add the found user object to the 'Enterprise Admins' group.

.NOTES
Author:      AI Assistant
Version:     3.0 (Find User First, Target Specific Parent DC)
Prerequisites:
    - Active Directory PowerShell module must be installed and available.
    - The script must be run with an account that has permissions to:
        a) Read user objects in 'sinnoh.pokemon.local'.
        b) Modify the 'Enterprise Admins' group in 'pokemon.local' (e.g., Domain Admin in pokemon.local).
    - Network connectivity and DNS resolution must work between the executing machine,
      the target child DC (if specified, or one discoverable), and dc04.pokemon.local.
    - Best run from a machine joined to the parent domain or a parent domain DC.

Security Warning: Adding users to 'Enterprise Admins' grants forest-wide administrative
                  privileges. Ensure this action is absolutely necessary.

.EXAMPLE
.\Add-CynthiaToEnterpriseAdmins_V3.ps1
(Ensure variables like $childDomainController are set correctly if needed)
#>

# --- Configuration ---
$userName = "cynthia"
$childDomain = "sinnoh.pokemon.local"
$parentDomain = "pokemon.local" # Domain where the target group resides
$enterpriseAdminsGroup = "Enterprise Admins"

# Specify the FQDN of the DC in the PARENT domain where the group modification MUST occur
$parentDomainControllerTarget = "dc04.pokemon.local" 

# Optional: Specify a DC FQDN in the CHILD domain ('sinnoh.pokemon.local') to search for the user.
# Leave empty ("") to auto-discover a DC in the child domain.
$childDomainController = "Arceus.sinnoh.pokemon.local" 
# Example: $childDomainController = "sinnoh-dc1.sinnoh.pokemon.local"

# --- Script Body ---

# Check if the Active Directory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Active Directory PowerShell module not found. Please install Remote Server Administration Tools (RSAT) for AD DS or run this on a Domain Controller."
    exit 1
} else {
    Import-Module ActiveDirectory
}

# --- Highly Critical Action Warning ---
Write-Warning "This script will attempt to find '$userName'@'$childDomain' and add them to '$enterpriseAdminsGroup'."
Write-Warning "The addition will be performed specifically on the parent DC: '$parentDomainControllerTarget'."
Write-Warning "MEMBERSHIP IN '$enterpriseAdminsGroup' GRANTS FOREST-WIDE ADMINISTRATIVE PRIVILEGES."
Write-Warning "Ensure this action is intended and necessary, and you are running with appropriate permissions."
# Optional: Add a confirmation prompt
# $confirmation = Read-Host "Do you want to proceed? (Y/N)"
# if ($confirmation -ne 'Y') { Write-Host "Operation cancelled."; exit }

$userObject = $null # Initialize variable

# --- Step 1: Find the user in the child domain ---
Write-Host "Attempting to find user '$userName' in domain '$childDomain'..."

# Determine the server parameter for Get-ADUser (target child DC)
$getUserParams = @{
    Identity = $userName
    ErrorAction = 'Stop' # Stop on error within the try block
}

# Try to use the specified child DC, test connectivity first
if (-not [string]::IsNullOrEmpty($childDomainController)) {
    Write-Host "Checking specified child domain controller: $childDomainController"
    if (Test-Connection -ComputerName $childDomainController -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host "Using specified child domain controller: $childDomainController"
        $getUserParams.Add("Server", $childDomainController)
    } else {
        Write-Warning "Specified Child Domain Controller '$childDomainController' is not reachable. Attempting auto-discovery in '$childDomain'."
        # If specified DC is bad, fall through to auto-discovery
    }
} 

# If no valid specified child DC, attempt auto-discovery in the child domain
if (-not $getUserParams.ContainsKey("Server")) {
     try {
        Write-Host "Auto-discovering a Domain Controller in '$childDomain'..."
        # Discover any available DC in the specified domain
        $discoveredChildDC = Get-ADDomainController -DomainName $childDomain -Discover -ErrorAction Stop
        if ($discoveredChildDC) {
             $getUserParams.Add("Server", $discoveredChildDC.HostName)
             Write-Host "Using auto-discovered child domain controller: $($discoveredChildDC.HostName)"
        } else {
             # This case might be rare if Get-ADDomainController doesn't error, but good to check
             Write-Error "Could not auto-discover a Domain Controller in '$childDomain'."
             exit 1 # Exit if we cannot find a DC to query
        }
     } catch {
         Write-Error "Failed to auto-discover a Domain Controller in '$childDomain'. Error: $($_.Exception.Message)"
         Write-Error "Check DNS and network connectivity to the child domain '$childDomain'."
         exit 1 # Exit if we cannot find a DC to query
     }
}

# Now, try to get the user using the determined child DC
try {
    Write-Host "Querying server '$($getUserParams.Server)' for user '$userName'..."
    $userObject = Get-ADUser @getUserParams
    Write-Host "[SUCCESS] Found user '$userName' in '$childDomain'. User DN: $($userObject.DistinguishedName)"
} catch {
    Write-Error "[FAILURE] Could not find user '$userName' using DC '$($getUserParams.Server)'."
    Write-Error "Error details: $($_.Exception.Message)"
    Write-Error "Verify user '$userName' exists in '$childDomain' and the account running script has read permissions there."
    exit 1 # Exit if user not found
}

# --- Step 2: Add the found user to the group on the specific parent DC ---
if ($userObject) {
    Write-Host "Attempting to add user '$($userObject.SamAccountName)' (SID: $($userObject.SID)) to group '$enterpriseAdminsGroup' on parent DC '$parentDomainControllerTarget'..."

    # Construct parameters for Add-AdGroupMember
    $addParams = @{
        Identity    = $enterpriseAdminsGroup
        Members     = $userObject # Pass the entire user object found in Step 1
        Server      = $parentDomainControllerTarget # Target specific parent DC for the ADD operation
        ErrorAction = 'Stop' 
    }

    # Check connectivity to the target parent DC before attempting the add operation
     Write-Host "Checking connectivity to target parent DC: $parentDomainControllerTarget"
    if (-not (Test-Connection -ComputerName $parentDomainControllerTarget -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
         Write-Error "[FAILURE] Cannot reach target parent domain controller '$parentDomainControllerTarget'. Cannot proceed with group modification."
         exit 1
    }

    try {
        # Execute the command to add the user to the group
        Add-AdGroupMember @addParams
        Write-Host "[SUCCESS] User '$($userObject.SamAccountName)' added to '$enterpriseAdminsGroup' on '$parentDomainControllerTarget'."

        # Optional: Verification step (can still use the same parent DC)
        Write-Host "Verifying membership on '$parentDomainControllerTarget' (may take time for replication)..."
        $verifyGroupParams = @{ Identity = $enterpriseAdminsGroup; Server = $parentDomainControllerTarget }
        $groupMembers = Get-ADGroupMember @verifyGroupParams -ErrorAction SilentlyContinue
        if ($groupMembers -ne $null -and ($groupMembers | Where-Object {$_.SID -eq $userObject.SID})) {
             Write-Host "[VERIFIED] '$($userObject.SamAccountName)' confirmed as a member of '$enterpriseAdminsGroup'."
        } else {
             Write-Warning "[VERIFICATION FAILED/DELAYED] Could not confirm '$($userObject.SamAccountName)' in '$enterpriseAdminsGroup' membership list immediately on '$parentDomainControllerTarget'. Check manually or allow time for replication."
        }

    } catch {
        Write-Error "[FAILURE] Failed to add user '$($userObject.SamAccountName)' to group '$enterpriseAdminsGroup' on '$parentDomainControllerTarget'."
        Write-Error "Error details: $($_.Exception.Message)"
        Write-Error "Verify the account running the script has permission to modify '$enterpriseAdminsGroup' on '$parentDomainControllerTarget'."
    }
} else {
    # This part should technically not be reached due to the exit 1 after the first try/catch failure, but good practice
    Write-Error "[FAILURE] User object for '$userName' was not retrieved successfully. Cannot proceed with adding to group."
}