# --- EXTREMELY IMPORTANT WARNINGS ---
# 1. This script is for EDUCATIONAL AND ILLUSTRATIVE PURPOSES ONLY.
# 2. DO NOT USE REAL CREDENTIALS. The provided credentials are examples.
# 3. This script MODIFIES SYSTEM REGISTRY SETTINGS (SMB Signing).
#    While it attempts to revert them, errors could leave your system in an altered state.
# 4. Disabling SMB signing reduces security. This should only be done in isolated, controlled test environments.
# 5. RUNNING THIS SCRIPT REQUIRES ADMINISTRATIVE PRIVILEGES.
# 6. Understand the risks before proceeding. Use in a VM is highly recommended.
# --- END WARNINGS ---

# Enable WDigest credential caching
Write-Host "[*] Enabling WDigest plaintext credential caching..." -ForegroundColor Cyan
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "UseLogonCredential" -Value 1 -Type DWord
Write-Host "[+] WDigest 'UseLogonCredential' set to 1." -ForegroundColor Green



# Hardcoded credentials and target as per your request
$TargetIP = "127.0.0.1"       # Loopback address
$ShareName = "C$"             # Administrative share (requires user to be admin on target)
$RemoteShare = "\\$TargetIP\$ShareName"
$Username = "sinnoh.pokemon.local\cynthia" # Example domain user
$Password = "G4rch0Mp_OP_lmao!!"          # Example password

# Function to check for admin rights
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Verify Administrator Privileges
if (-not (Test-IsAdmin)) {
    Write-Error "This script requires administrative privileges to modify SMB signing settings. Please re-run as Administrator."
    # Removed Read-Host for non-interactive environments
    exit 1 # Exit with an error code
}
Write-Host "Administrator privileges confirmed." -ForegroundColor Green

# SMB Client Signing registry path and value names
$SmbClientRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
$RequireSignName = "RequireSecuritySignature"
$EnableSignName = "EnableSecuritySignature"

# Variables to store original SMB signing settings
$OriginalRequireValue = $null
$OriginalEnableValue = $null
$RequireExisted = $false
$EnableExisted = $false
$CanManageSmbSettings = $false # Flag to indicate if we can manage SMB settings

# Main script block with error handling for SMB settings
try {
    Write-Host "`n--- Managing SMB Client Signing Settings ---"

    if (Test-Path $SmbClientRegPath) {
        # Check if RequireSecuritySignature VALUE exists
        if (Get-ItemProperty -Path $SmbClientRegPath -Name $RequireSignName -ErrorAction SilentlyContinue) {
            $OriginalRequireValue = (Get-ItemProperty -Path $SmbClientRegPath -Name $RequireSignName).$RequireSignName
            $RequireExisted = $true
        } else {
            $OriginalRequireValue = 0 # Typical default if not explicitly set (client does not require signing)
            $RequireExisted = $false
            Write-Host "Registry value '$RequireSignName' not found. Assuming default behavior (0)."
        }

        # Check if EnableSecuritySignature VALUE exists
        if (Get-ItemProperty -Path $SmbClientRegPath -Name $EnableSignName -ErrorAction SilentlyContinue) {
            $OriginalEnableValue = (Get-ItemProperty -Path $SmbClientRegPath -Name $EnableSignName).$EnableSignName
            $EnableExisted = $true
        } else {
            $OriginalEnableValue = 1 # Typical default for workstations if not explicitly set (client enables/prefers signing)
            $EnableExisted = $false
            Write-Host "Registry value '$EnableSignName' not found. Assuming default behavior (1)."
        }
        $CanManageSmbSettings = $true
    } else {
        Write-Warning "SMB Client registry key '$SmbClientRegPath' not found! Cannot manage SMB signing."
        Write-Warning "Proceeding without altering SMB signing settings."
    }

    if ($CanManageSmbSettings) {
        Write-Host "Original SMB Client settings (or assumed defaults if not explicitly set):"
        Write-Host "  $RequireSignName : $OriginalRequireValue (Existed: $RequireExisted)"
        Write-Host "  $EnableSignName  : $OriginalEnableValue (Existed: $EnableExisted)"

        Write-Host "Attempting to disable SMB client signing (setting both to 0)..."
        # Ensure the Parameters key exists (it should, but for safety)
        if (-not (Test-Path $SmbClientRegPath)) {
            New-Item -Path $SmbClientRegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $SmbClientRegPath -Name $RequireSignName -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $SmbClientRegPath -Name $EnableSignName -Value 0 -Type DWord -Force
        Write-Host "SMB client signing (RequireSecuritySignature & EnableSecuritySignature) set to 0." -ForegroundColor Yellow
        Write-Host "Note: For these settings to reliably affect all new connections, a restart of the 'Workstation'"
        Write-Host "service or a system reboot might sometimes be necessary, though often new connections pick it up."
        Start-Sleep -Seconds 2 # Brief pause
    }

    # --- Credential Caching Attempt ---
    Write-Host "`n--- Starting Credential Caching Attempt ---"
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $CredentialObj = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

    Write-Host "Attempting to map network drive to '$RemoteShare' with hardcoded credentials..."
    Write-Host "Username: $Username"
    Write-Host "Target: $RemoteShare"

    try {
        New-PSDrive -Name "X" -PSProvider FileSystem -Root $RemoteShare -Credential $CredentialObj -ErrorAction Stop
        Write-Host "Network drive X mapped successfully to '$RemoteShare'." -ForegroundColor Green
        Write-Host "Credentials for '$Username' are very likely cached in LSASS memory now."

        # Keep drive mapped for a few seconds for demonstration
        Write-Host "Drive X will be unmapped in 5 seconds..."
        Start-Sleep -Seconds 5
        Remove-PSDrive -Name "X" -Force -ErrorAction SilentlyContinue
        Write-Host "Network drive X unmapped."
    } catch {
        Write-Warning "Failed to map network drive. Error: $($_.Exception.Message)"
        Write-Warning "Even if the mapping failed, an authentication attempt with the provided credentials was made."
        Write-Warning "This means the credentials for '$Username' might still have been processed by LSASS and could be cached."
    }
    Write-Host "--- Credential Caching Attempt Finished ---`n"

} catch {
    Write-Error "An unexpected error occurred in the main script block: $($_.Exception.Message)"
} finally {
    # Revert SMB signing settings
    if ($CanManageSmbSettings) {
        Write-Host "--- Reverting SMB Client Signing Settings ---"
        try {
            Write-Host "Attempting to revert '$RequireSignName' to '$OriginalRequireValue' (Existed: $RequireExisted)"
            Set-ItemProperty -Path $SmbClientRegPath -Name $RequireSignName -Value $OriginalRequireValue -Type DWord -Force

            Write-Host "Attempting to revert '$EnableSignName' to '$OriginalEnableValue' (Existed: $EnableExisted)"
            Set-ItemProperty -Path $SmbClientRegPath -Name $EnableSignName -Value $OriginalEnableValue -Type DWord -Force
            
            Write-Host "SMB client signing settings should now be reverted to their original state (or typical defaults)." -ForegroundColor Green
            Write-Host "Current values after revert attempt:"
            $CurrentRequire = (Get-ItemProperty -Path $SmbClientRegPath -Name $RequireSignName -ErrorAction SilentlyContinue).$RequireSignName
            $CurrentEnable = (Get-ItemProperty -Path $SmbClientRegPath -Name $EnableSignName -ErrorAction SilentlyContinue).$EnableSignName
            Write-Host "  $RequireSignName : $CurrentRequire"
            Write-Host "  $EnableSignName  : $CurrentEnable"
        } catch {
            Write-Error "CRITICAL: Failed to revert SMB signing settings. Manual check and correction IS REQUIRED."
            Write-Error "Error details: $($_.Exception.Message)"
            Write-Warning "Registry Path: $SmbClientRegPath"
            Write-Warning "Target original values were: Require=$OriginalRequireValue, Enable=$OriginalEnableValue"
        }
    }
}

Write-Host "`n--- SCRIPT EXECUTION FINISHED ---"
Write-Host "If this script was run on a system where an attacker subsequently gained admin rights,"
Write-Host "and if the credentials for '$Username' were cached by LSASS during the network drive mapping attempt,"
Write-Host "tools like Mimikatz could potentially extract them."
# Removed final Read-Host for non-interactive environments