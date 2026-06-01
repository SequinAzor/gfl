# ============================================================
# Active Directory Administration Tool
# Author  : Hugo Brito
# Company : GFL
# ============================================================

Import-Module ActiveDirectory
Import-Module AdmPwd.PS   # Required for LAPS password retrieval

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

function Pause {
    Read-Host "`nPress ENTER to continue"
}

function Write-Header {
    param (
        [string]$Title
    )

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host ("║ {0,-46} ║" -f $Title) -ForegroundColor DarkGray
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor DarkGray
}

# Low Risk / Domain User Highlight ===============================================
function Get-AllUserGroups {
    param ([Microsoft.ActiveDirectory.Management.ADUser]$User)

    try {
        Get-ADPrincipalGroupMembership -Identity $User |
        Sort-Object Name |
        ForEach-Object {
            if ($_.Name -in @("Domain Users", "Low Risk Users")) {
                Write-Host " $($_.Name)" -ForegroundColor Green
            } else {
                Write-Host " $($_.Name)"
            }
        }
    }
    catch {
        Write-Host "Unable to retrieve group membership." -ForegroundColor Red
    }
}

# LOCKOUT (Yes or No) ============================================================
function Get-LockStatus {
    param (
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )

    if ($User.LockedOut) {
        return "YES"
    }
    else {
        return "NO"
    }
}

function Write-LockStatus {
    param (
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )

    if ($User.LockedOut) {
        Write-Host " Account Locked  : YES" -ForegroundColor Red
    }
    else {
        Write-Host " Account Locked  : NO" -ForegroundColor Green
    }
}

# ACCOUNT STATUS (Enabled / Disabled) ============================================
function Write-AccountStatus {
    param (
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )

    if ($User.Enabled) {
        Write-Host " Account Status  : ENABLED" -ForegroundColor Green
    }
    else {
        Write-Host " Account Status  : DISABLED" -ForegroundColor Red
    }
}


# USER ACTION – PRINTER CARD ID MANAGEMENT ========================================
function Manage-PrinterCardForUser {
    param (
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )

    $user = Get-ADUser $User.SamAccountName `
        -Properties extensionAttribute2, extensionAttribute3

    $ext2 = if ($user.extensionAttribute2) { $user.extensionAttribute2 } else { "<not set>" }
    $ext3 = if ($user.extensionAttribute3) { $user.extensionAttribute3 } else { "<not set>" }

    Write-Header "PRINTER CARD ID"
    Write-Host " ExtensionAttribute2 : $ext2"
    Write-Host " ExtensionAttribute3 : $ext3"
    Write-Host ""

    Write-Host " [1] Add / Change Printer Card ID"
    Write-Host " [2] Remove Printer Card ID"
    Write-Host ""

    $action = Read-Host "Select option"

    switch ($action) {

        # -------------------------------
        # ADD / CHANGE
        # -------------------------------
        "1" {
            Write-Host ""
            Write-Host " [1] ExtensionAttribute2"
            Write-Host " [2] ExtensionAttribute3"
            Write-Host " [3] Both"
            Write-Host ""

            $choice = Read-Host "Select option"
            $value  = Read-Host "Enter new Printer Card ID"

            switch ($choice) {
                "1" {
                    Set-ADUser -Identity $user.SamAccountName `
                        -Replace @{ extensionAttribute2 = $value }
                }
                "2" {
                    Set-ADUser -Identity $user.SamAccountName `
                        -Replace @{ extensionAttribute3 = $value }
                }
                "3" {
                    Set-ADUser -Identity $user.SamAccountName `
                        -Replace @{
                            extensionAttribute2 = $value
                            extensionAttribute3 = $value
                        }
                }
                default {
                    Write-Host "Invalid selection." -ForegroundColor Red
                    Pause
                    return
                }
            }

            Write-Host "Printer Card ID updated successfully." -ForegroundColor Green
        }

        # -------------------------------
        # REMOVE
        # -------------------------------
        "2" {
            Write-Host ""
            Write-Host " [1] ExtensionAttribute2"
            Write-Host " [2] ExtensionAttribute3"
            Write-Host " [3] Both"
            Write-Host ""

            $choice = Read-Host "Select option"

            switch ($choice) {
                "1" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute2 }
                "2" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute3 }
                "3" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute2, extensionAttribute3 }
                default {
                    Write-Host "Invalid selection." -ForegroundColor Red
                    Pause
                    return
                }
            }

            Write-Host "Printer Card ID removed successfully." -ForegroundColor Green
        }

        default { return }
    }

    #Pause
}

# RESET + UNLOCK COMBINED ACTION
# Unlock Account Only =================================================
# Manage Account Expiration
# Used for Option 1 - Search by Username/Full Name

function Reset-AndUnlockUser {
    param (
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )

    Write-Header "USER ACTIONS"
    Write-Host " [1] Reset Password + Unlock Account"
    Write-Host " [2] Unlock Account Only"
    Write-Host " [3] Manage Account Expiration"
    Write-Host " [4] Change Printer Card ID"
    Write-Host " [5] Show User OU Location"
    Write-Host ""

    $action = Read-Host "Select option"

    switch ($action) {

        # ============================================================
        # OPTION 1 – RESET PASSWORD + UNLOCK
        # ============================================================
        "1" {
            try {
                $newPassword = Read-Host "Enter NEW password" -AsSecureString

                Set-ADAccountPassword -Identity $User.SamAccountName `
                    -Reset `
                    -NewPassword $newPassword `
                    -ErrorAction Stop

                if ($User.LockedOut) {
                    Unlock-ADAccount -Identity $User.SamAccountName -ErrorAction Stop
                }

                Write-Host "Password reset and account unlocked successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to reset password or unlock account." -ForegroundColor Red
            }
        }

        # ============================================================
        # OPTION 2 – UNLOCK ACCOUNT ONLY
        # ============================================================
        "2" {
            try {
                if ($User.LockedOut) {
                    Unlock-ADAccount -Identity $User.SamAccountName -ErrorAction Stop
                    Write-Host "Account unlocked successfully." -ForegroundColor Green
                }
                else {
                    Write-Host "User account is not locked." -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "Failed to unlock account." -ForegroundColor Red
            }
        }

         # ============================================================
         # OPTION 3 – ACCOUNT EXPIRATION MANAGEMENT (FIXED)
         # ============================================================
         "3" {
            try {
                $userWithExpiry = Get-ADUser $User.SamAccountName `
                    -Properties AccountExpirationDate, extensionAttribute11

                $currentExpiration = if ($userWithExpiry.AccountExpirationDate) {
                    $userWithExpiry.AccountExpirationDate.ToString("yyyy-MM-dd")
                } else {
                    "NEVER"
                }

                # ================================
                # EXTENSION ATTRIBUTE 11 CHECK
                # ================================
                $ext11 = $userWithExpiry.extensionAttribute11
                $isVendor = $false

                if ([string]::IsNullOrWhiteSpace($ext11)) {
                    $ext11Display = "<not set>"
                    $ext11Color = "Green"
                }
                elseif ($ext11 -in @("VendorAccount","VendorAccountElevated")) {
                    $ext11Display = $ext11
                    $ext11Color = "Red"
                    $isVendor = $true
                }
                elseif ($ext11 -eq "EmployeeAccount") {
                    $ext11Display = $ext11
                    $ext11Color = "Green"
                }
                else {
                    $ext11Display = $ext11
                    $ext11Color = "Green"
                }

                Write-Header "ACCOUNT EXPIRATION"

                Write-Host " Full Name          : $($User.Name)"
                Write-Host " Username           : $($User.SamAccountName)"
                Write-Host " Current Expiration : $currentExpiration"
                Write-Host ""

                Write-Host -NoNewline " AttributeExtension11 : "
                Write-Host "$ext11Display" -ForegroundColor $ext11Color
                Write-Host ""

                # ================================
                # VENDOR GOVERNANCE WARNING
                # ================================
                if ($isVendor) {
                    Write-Host "--------------------------------------------------------------------------" -ForegroundColor Red
                    Write-Host "This account is a managed Vendor Account controlled by the monthly Saviynt Certification process." -ForegroundColor Red
                    Write-Host "Expiry dates are no longer manually adjusted for these accounts." -ForegroundColor Red
                    Write-Host "Access is maintained by the account owner completing their monthly review." -ForegroundColor Red
                    Write-Host "Please contact your GFL Manager to ensure they have completed their certification in the Saviynt Identity Portal." -ForegroundColor Red
                    Write-Host "--------------------------------------------------------------------------" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "• Copy/Paste this Template to the Additional Comments" -ForegroundColor Yellow
                    Write-Host "• Mark this Task as "Closed Skipped"" -ForegroundColor Yellow
                    Write-Host ""
                    }

                    Write-Host " [1] Set / Change Expiration Date"
                    Write-Host " [2] Remove Expiration (Never Expires)"
                    Write-Host ""
                    $expChoice = Read-Host "Select option"

                switch ($expChoice) {

                    "1" {
                        Write-Host ""
                        Write-Host "User will be active for the whole day you enter."
                        Write-Host "Enter expiration date in format: YYYY-MM-DD"
                        $dateInput = Read-Host "Expiration Date"

                        try {
                            $baseDate = [DateTime]::ParseExact($dateInput, "yyyy-MM-dd", $null)

                            $newDate = Get-Date `
                                -Year $baseDate.Year `
                                -Month $baseDate.Month `
                                -Day $baseDate.Day `
                                -Hour 23 `
                                -Minute 59 `
                                -Second 59

                            Set-ADUser -Identity $User.SamAccountName `
                                -AccountExpirationDate $newDate

                            Write-Host "Account expiration updated to $($newDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Invalid date format or update failed." -ForegroundColor Red
                        }
                    }

                    "2" {
                        try {
                            Set-ADUser -Identity $User.SamAccountName -AccountExpirationDate $null
                            Write-Host "Account expiration removed (Never Expires)." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Failed to remove expiration date." -ForegroundColor Red
                        }
                    }
                }
            }
            catch {
                Write-Host "Failed to retrieve or manage account expiration." -ForegroundColor Red
            }
        }


        # ============================================================
        # OPTION 4 – PRINTER CARD ID MANAGEMENT
        # ============================================================
        "4" {
            Manage-PrinterCardForUser -User $User
        }

        # ============================================================
        # OPTION 5 – USER OU LOCATION
        # ============================================================
        "5" {
            try {
                $userDN = (Get-ADUser $User.SamAccountName -Properties DistinguishedName).DistinguishedName
                $ouPath = ($userDN -split ',' |
                          Where-Object { $_ -like "OU=*" } |
                          ForEach-Object { $_ -replace '^OU=', '' }) -join " → "

                Write-Header "USER OBJECT LOCATION"
                Write-Host " Full Name : $($User.Name)"
                Write-Host " Username  : $($User.SamAccountName)"
                Write-Host " OU Path   : $ouPath"
            }
            catch {
                Write-Host "Unable to retrieve user OU location." -ForegroundColor Red
            }

            Pause
        }

        default { return }
    }
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {
    Clear-Host
    Write-Header "ACTIVE DIRECTORY ADMINISTRATION TOOL"

    Write-Host ""
    Write-Host "  USER SEARCH"
    Write-Host "  ───────────"
    Write-Host "   [1]  Search by Username/Full Name"
    Write-Host "   [2]  Search by Employee ID"
    Write-Host "   [3]  Search Printer Card by ID"    
    Write-Host ""

    Write-Host "  USER MANAGEMENT"
    Write-Host "  ───────────────"
    Write-Host "   [4]  User Group Management"
    Write-Host ""

    Write-Host "  SYSTEM TOOLS"
    Write-Host "  ────────────"
    Write-Host "   [5]  Retrieve LAPS Password"
       
       
    Write-Host ""
    
    Write-Host "──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host " GFL • Hugo Brito" -ForegroundColor DarkGray
    Write-Host "──────────────────────────────────────────────────" -ForegroundColor DarkGray
}

# ============================================================
# OPTION 1 – SEARCH BY USERNAME OR FULL NAME
# ============================================================

function Search-User {
    Clear-Host
    Write-Header "SEARCH USER"

    $input = Read-Host "Enter Username/Full Name"
    $input = $input.Trim()

    try {

        # =========================================================
        # SEARCH USERS (USERNAME OR PARTIAL NAME)
        # =========================================================
        $results = Get-ADUser -Filter "
            SamAccountName -like '*$input*' -or
            Name -like '*$input*' -or
            DisplayName -like '*$input*' -or
            GivenName -like '*$input*' -or
            Surname -like '*$input*'
        " -Properties DisplayName, SamAccountName

        if (-not $results) {
            throw "No users found"
        }

        # Force array
        $results = @($results)

        # =========================================================
        # MULTIPLE RESULTS → SELECTION MENU
        # =========================================================
        if ($results.Count -gt 1) {

            Write-Header "MULTIPLE USERS FOUND"

            for ($i = 0; $i -lt $results.Count; $i++) {
                Write-Host " [$($i + 1)] $($results[$i].DisplayName) ($($results[$i].SamAccountName))"
            }

            $choice = Read-Host "`nSelect user number"

            if ($choice -notmatch '^\d+$' -or
                [int]$choice -lt 1 -or
                [int]$choice -gt $results.Count) {

                throw "Invalid selection"
            }

            $selectedSam = [string]$results[[int]$choice - 1].SamAccountName
        }
        else {
            $selectedSam = [string]$results[0].SamAccountName
        }

        # =========================================================
        # CLEAN & VALIDATE SAMACCOUNTNAME  (CRITICAL FIX)
        # =========================================================
        $selectedSam = $selectedSam.Trim()

        if ([string]::IsNullOrWhiteSpace($selectedSam)) {
            throw "Invalid SamAccountName selected"
        }

        # =========================================================
        # FINAL SAFE USER RESOLUTION
        # =========================================================
        $user = Get-ADUser -Identity $selectedSam -Properties * -ErrorAction Stop

        # =========================================================
        # SAFE PROPERTY HANDLING
        # =========================================================
        $manager = if ($user.Manager) {
            try { (Get-ADUser $user.Manager -Properties Name).Name }
            catch { "N/A" }
        } else { "N/A" }

        $ext2 = if ($user.extensionAttribute2) { $user.extensionAttribute2 } else { "Not Set" }
        $ext3 = if ($user.extensionAttribute3) { $user.extensionAttribute3 } else { "Not Set" }
        $telephone = if ($user.telephoneNumber) { $user.telephoneNumber } else { "Not Set" }
        $mobile = if ($user.mobile) { $user.mobile } else { "Not Set" }
        $email = if ($user.mail) { $user.mail } else { "Not Set" }

        # =========================================================
        # DISPLAY USER INFO
        # =========================================================
        Write-Header "USER INFORMATION"
        Write-Host " Full Name       : $($user.DisplayName)"
        Write-Host " Username        : $($user.SamAccountName)"
        Write-Host " Email           : $email"
        Write-Host " Employee ID     : $($user.EmployeeID)"
        Write-Host " Telephone       : $telephone"
        Write-Host " Mobile          : $mobile"
        Write-LockStatus $user
        Write-AccountStatus $user
        Write-Host " Job Title       : $($user.Title)"
        Write-Host " Location        : $($user.Office)"
        Write-Host " Manager         : $manager"

        Write-Header "PRINTER CARD ID"
        Write-Host " ExtensionAttribute2 : $ext2"
        Write-Host " ExtensionAttribute3 : $ext3"

        Write-Header "ACTIVE DIRECTORY GROUPS"
        Get-AllUserGroups $user

        Reset-AndUnlockUser -User $user
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Pause
}


# ============================================================
# OPTION 2 – SEARCH BY EMPLOYEE ID
# ============================================================

function Search-ByEmployeeID {
    Clear-Host
    Write-Header "SEARCH USER BY EMPLOYEE ID"

    $empID = Read-Host "Enter Employee ID"

    try {
        $user = Get-ADUser -Filter "EmployeeID -eq '$empID'" -Properties Manager, Title, EmployeeID, LockedOut, telephoneNumber, mobile, mail
        if (-not $user) { throw }

        $email = if ([string]::IsNullOrWhiteSpace($user.mail)) { "Not Set" } else { $user.mail }

        Write-Header "USER INFORMATION"
        Write-Host " Full Name       : $($user.Name)"
        Write-Host " Username        : $($user.SamAccountName)"
        Write-Host " Email           : $email"
        Write-Host " Employee ID     : $($user.EmployeeID)"
        Write-Host " Telephone       : $telephone"
        Write-Host " Mobile          : $mobile"
        Write-LockStatus -User $user
        Write-AccountStatus $user
        Write-Host " Job Title       : $($user.Title)"

        Write-Header "ACTIVE DIRECTORY GROUPS"
        Get-AllUserGroups -User $user

        Reset-AndUnlockUser -User $user
    }
    catch {
        Write-Host "Employee ID not found." -ForegroundColor Red
    }

    Pause
}

# ============================================================ 
# OPTION 3 – SEARCH BY PRINTER CARD ID (WITH EDIT / REMOVE) 
# ============================================================ 

function Search-ByPrinterCardID {

    Clear-Host
    Write-Header "SEARCH BY PRINTER CARD ID"

    $cardID = Read-Host "Enter Printer Card ID"

    if ([string]::IsNullOrWhiteSpace($cardID)) {
        Write-Host "Printer Card ID cannot be empty." -ForegroundColor Red
        Pause
        return
    }

    $cardID = $cardID.Trim()

    try {

        # Pull users that have either attribute populated
        $allUsers = Get-ADUser -Filter "extensionAttribute2 -like '*' -or extensionAttribute3 -like '*'" `
            -Properties extensionAttribute2, extensionAttribute3, Manager, Title, Office, EmployeeID, LockedOut, Enabled

        # Safe PowerShell filtering (trimmed comparison)
        $users = $allUsers | Where-Object {
            ($_.extensionAttribute2 -and $_.extensionAttribute2.Trim() -eq $cardID) -or
            ($_.extensionAttribute3 -and $_.extensionAttribute3.Trim() -eq $cardID)
        }

        if (-not $users) {
            Write-Host "No users found with that Printer Card ID." -ForegroundColor Red
            Pause
            return
        }

        $users = @($users)

        Write-Header "USERS ASSIGNED TO THIS PRINTER CARD ID"

        for ($i = 0; $i -lt $users.Count; $i++) {

            $ext2 = if ([string]::IsNullOrWhiteSpace($users[$i].extensionAttribute2)) { "<not set>" } else { $users[$i].extensionAttribute2 }
            $ext3 = if ([string]::IsNullOrWhiteSpace($users[$i].extensionAttribute3)) { "<not set>" } else { $users[$i].extensionAttribute3 }

            Write-Host " [$($i + 1)] $($users[$i].Name) ($($users[$i].SamAccountName))"
            Write-Host "      Employee ID : $($users[$i].EmployeeID)"
            Write-Host "      ExtAttr2    : $ext2"
            Write-Host "      ExtAttr3    : $ext3"

            if ($users[$i].LockedOut) {
                Write-Host "      Account Locked : YES" -ForegroundColor Red
            }
            else {
                Write-Host "      Account Locked : NO" -ForegroundColor Green
            }

            Write-Host -NoNewline "      Account State  : "

            if ($users[$i].Enabled) {
            Write-Host "ENABLED" -ForegroundColor Green
            }
            else {
            Write-Host "DISABLED" -ForegroundColor Red
            }

            Write-Host ""
        }

        # Allow selection if multiple users
        if ($users.Count -gt 1) {
            $selection = Read-Host "Select user number to manage (or press ENTER to cancel)"

            if ([string]::IsNullOrWhiteSpace($selection)) {
                Pause
                return
            }

            if ($selection -notmatch '^\d+$' -or
                [int]$selection -lt 1 -or
                [int]$selection -gt $users.Count) {

                Write-Host "Invalid selection." -ForegroundColor Red
                Pause
                return
            }

            $user = $users[[int]$selection - 1]
        }
        else {
            $user = $users[0]
        }

        # ===============================
        # ACTION MENU
        # ===============================
        Write-Header "PRINTER CARD ID ACTIONS"
        Write-Host " [1] Add / Change Printer Card ID"
        Write-Host " [2] Remove Printer Card ID"
        Write-Host ""

        $action = Read-Host "Select option"

        switch ($action) {

            "1" {
                Write-Host ""
                Write-Host " [1] ExtensionAttribute2"
                Write-Host " [2] ExtensionAttribute3"
                Write-Host " [3] Both"

                $editChoice = Read-Host "Select option"
                $value = Read-Host "Enter new Printer Card ID"

                switch ($editChoice) {
                    "1" { Set-ADUser -Identity $user.SamAccountName -Replace @{ extensionAttribute2 = $value } }
                    "2" { Set-ADUser -Identity $user.SamAccountName -Replace @{ extensionAttribute3 = $value } }
                    "3" {
                        Set-ADUser -Identity $user.SamAccountName -Replace @{
                            extensionAttribute2 = $value
                            extensionAttribute3 = $value
                        }
                    }
                    default {
                        Write-Host "Invalid selection." -ForegroundColor Red
                        Pause
                        return
                    }
                }

                Write-Host "Printer Card ID updated successfully." -ForegroundColor Green
            }

            "2" {
                Write-Host ""
                Write-Host " [1] ExtensionAttribute2"
                Write-Host " [2] ExtensionAttribute3"
                Write-Host " [3] Both"

                $removeChoice = Read-Host "Select option"

                switch ($removeChoice) {
                    "1" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute2 }
                    "2" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute3 }
                    "3" { Set-ADUser -Identity $user.SamAccountName -Clear extensionAttribute2, extensionAttribute3 }
                    default {
                        Write-Host "Invalid selection." -ForegroundColor Red
                        Pause
                        return
                    }
                }

                Write-Host "Printer Card ID removed successfully." -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "Error searching Active Directory." -ForegroundColor Red
    }

    Pause
}


# ============================================================
# OPTION 4 - User Group Management
# ============================================================

# ============================================================
# Sub-Menu - AD Group Management 
# ============================================================

function Show-GroupManagementMenu {

    do {
        Clear-Host
        Write-Header "USER GROUP MANAGEMENT"

        Write-Host ""
        Write-Host " [1] Search AD Groups"
        Write-Host " [2] Mirror Access (AD Groups)"
        Write-Host " [3] Add Groups to User (Menu)"
        Write-Host " [4] Manually Add Groups (Paste)"
        Write-Host " [5] Remove Groups from User"
        Write-Host ""
        
        $choice = Read-Host "Select an option"

        if ([string]::IsNullOrWhiteSpace($choice)) {
            return
        }

        switch ($choice) {
            "1" { Search-ADGroupsByPartialName }
            "2" { Mirror-UserGroups }
            "3" { Add-GroupsToUser }
            "4" { Add-GroupsManually }
            "5" { Remove-GroupsFromUser }
            default {
                Write-Host "Invalid option." -ForegroundColor Red
                Pause
            }
        }
    }
    while ($true)
}

# ============================================================
# Sub-Menu - OPTION 1 – SEARCH AD GROUPS BY PARTIAL NAME
# ============================================================

function Search-ADGroupsByPartialName {
    Clear-Host
    Write-Header "SEARCH AD GROUPS BY PARTIAL NAME"

    $searchText = Read-Host "Enter part of the group name"

    if ([string]::IsNullOrWhiteSpace($searchText)) {
        Write-Host "Search text cannot be empty." -ForegroundColor Red
        Pause
        return
    }

    try {
        $groups = Get-ADGroup -Filter "Name -like '*$searchText*'" |
                  Sort-Object Name

        if (-not $groups -or $groups.Count -eq 0) {
            Write-Host "`nNo groups found matching '$searchText'." -ForegroundColor Yellow
            Pause
            return
        }

        Write-Header "MATCHING GROUPS"

        for ($i = 0; $i -lt $groups.Count; $i++) {
            Write-Host " [$($i + 1)] $($groups[$i].Name)"
        }

        Write-Host "`nTotal groups found: $($groups.Count)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error searching Active Directory groups." -ForegroundColor Red
    }

    Pause
}

# ============================================================  
# Sub-Menu - OPTION 2 – MIRROR ACCESS (AD GROUPS) 
# ============================================================  

function Mirror-UserGroups { 
    Clear-Host 
    Write-Header "MIRROR USER ACCESS (AD GROUPS)" 

    Write-Host ""
    Write-Host " [1] Identify users by Username"
    Write-Host " [2] Identify users by Full Name"
    Write-Host ""

    $idChoice = Read-Host "Select identification method"

    switch ($idChoice) {

        "1" {
            $sourceInput = Read-Host "Enter SOURCE Username"
            $targetInput = Read-Host "Enter TARGET Username"

            try {
                $src = Get-ADUser $sourceInput -ErrorAction Stop
                $tgt = Get-ADUser $targetInput -ErrorAction Stop
            }
            catch {
                Write-Host "One or both users not found." -ForegroundColor Red
                Pause
                return
            }
        }

        "2" {
            $sourceInput = Read-Host "Enter SOURCE Full Name"
            $targetInput = Read-Host "Enter TARGET Full Name"

            try {
                $src = Get-ADUser -Filter "Name -eq '$sourceInput'" -ErrorAction Stop
                $tgt = Get-ADUser -Filter "Name -eq '$targetInput'" -ErrorAction Stop

                if (-not $src -or -not $tgt) { throw }
            }
            catch {
                Write-Host "One or both users not found." -ForegroundColor Red
                Pause
                return
            }
        }

        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            Pause
            return
        }
    }

    $groups = Get-ADPrincipalGroupMembership -Identity $src | 
              Where-Object { $_.Name -notin @("Domain Users", "Low Risk Users") } | 
              Sort-Object Name 

    if ($groups.Count -eq 0) { 
        Write-Host "No groups available to mirror." -ForegroundColor Yellow 
        Pause 
        return 
    } 

    Write-Header "SOURCE USER GROUPS" 

    for ($i = 0; $i -lt $groups.Count; $i++) { 
        Write-Host " [$($i + 1)] $($groups[$i].Name)" 
    } 

    $selection = Read-Host "`nEnter group number(s) to copy (comma separated)" 

    $selectedGroups = $selection -split "," | 
        ForEach-Object { $_.Trim() } | 
        Where-Object { $_ -match '^\d+$' -and $_ -ge 1 -and $_ -le $groups.Count } | 
        ForEach-Object { $groups[$_ - 1] } 

    if ($selectedGroups.Count -eq 0) { 
        Write-Host "No valid groups selected." -ForegroundColor Red 
        Pause 
        return 
    } 

    Write-Header "COPYING GROUPS" 

    foreach ($group in $selectedGroups) { 
        try { 
            Add-ADGroupMember -Identity $group -Members $tgt.SamAccountName -ErrorAction Stop 
            Write-Host "Added $($tgt.SamAccountName) to $($group.Name)" -ForegroundColor Green 
        } 
        catch { 
            Write-Host "Failed to add to $($group.Name)" -ForegroundColor Red 
        } 
    } 

    Pause 
}  

# ============================================================
# Sub-Menu - OPTION 3 – ADD AD GROUPS (MENU) — USERNAME OR FULL NAME
# ============================================================

function Add-GroupsToUser {
    Clear-Host
    Write-Header "ADD ACTIVE DIRECTORY GROUPS"

    $input = Read-Host "Enter Username or Full Name"
    $input = $input.Trim()

    try {
        # Try exact username first
        $users = Get-ADUser -Filter "SamAccountName -eq '$input'" -Properties DisplayName, Enabled -ErrorAction SilentlyContinue

        # Fallback to name search
        if (-not $users) {
            $users = Get-ADUser -Filter "
                Name -like '*$input*' -or
                DisplayName -like '*$input*' -or
                GivenName -like '*$input*' -or
                Surname -like '*$input*'
            " -Properties DisplayName, SamAccountName, Enabled
        }

        if (-not $users) { throw }

        $users = @($users)

        if ($users.Count -gt 1) {
            Write-Header "MULTIPLE USERS FOUND"
            for ($i = 0; $i -lt $users.Count; $i++) {
                Write-Host " [$($i + 1)] $($users[$i].DisplayName) ($($users[$i].SamAccountName))"
            }

            $choice = Read-Host "`nSelect user number"
            if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt $users.Count) {
                throw
            }

            $user = $users[$choice - 1]
        }
        else {
            $user = $users[0]
        }

        # Refresh full object
        $user = Get-ADUser $user.SamAccountName -Properties DisplayName, Enabled -ErrorAction Stop
    }
    catch {
        Write-Host "User not found or invalid selection." -ForegroundColor Red
        Pause
        return
    }

    # ==========================================================
    # CACHE USER MEMBERSHIPS
    # ==========================================================
    $currentGroups = Get-ADPrincipalGroupMembership -Identity $user |
                     Select-Object -ExpandProperty Name

    # ==========================================================
    # FS1 / FS4 SECURITY GROUP BREAKDOWN
    # ==========================================================
    $fs1Groups = $currentGroups | Where-Object { $_ -like "*FS1*" } | Sort-Object
    $fs4Groups = $currentGroups | Where-Object { $_ -like "*FS4*" } | Sort-Object

    Clear-Host
    Write-Header "USER SECURITY GROUP OVERVIEW"

    Write-Host ""
    Write-Host " USER INFORMATION"
    Write-Host " ────────────────"
    Write-Host " Full Name : $($user.DisplayName)"
    Write-Host " Username  : $($user.SamAccountName)"

    Write-Host -NoNewline " Account Disabled : "
    if ($user.Enabled -eq $false) {
        Write-Host "YES" -ForegroundColor Red
    }
    else {
        Write-Host "NO" -ForegroundColor Green
    }

    # ---------------- FS1 ----------------
    Write-Host ""
    Write-Host " FS1 Security Groups"
    Write-Host " ───────────────────"

    if ($fs1Groups.Count -gt 0) {
        foreach ($group in $fs1Groups) {
            Write-Host "  • $group" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  None" -ForegroundColor DarkGray
    }

    # ---------------- FS4 ----------------
    Write-Host ""
    Write-Host " FS4 Security Groups"
    Write-Host " ───────────────────"

    if ($fs4Groups.Count -gt 0) {
        foreach ($group in $fs4Groups) {
            Write-Host "  • $group" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  None" -ForegroundColor DarkGray
    }

    # ---------------- GROUP CATEGORIES ----------------
    $GroupSections = [ordered]@{
        "Trux"                  = @("TRUX User Group","CTX - Trux - FS1","CTX - Trux - FS4","CTX - AWS - APP - Trux","CTX - AWS - APP - Trux DEV")
        "Tower"                 = @("CTX - Tower - FS1 - Migration","CTX - Tower - FS4","CTX - AWS - APP - Tower")
        "CieTrade"              = @("CTX - AWS - APP - Cietrade")
        "PC Scale"              = @("CTX - AWS - APP - PC Scale")
        "AMCS"                  = @("CTX - AMCS Platform Production - FS1","CTX - AMCS Platform Production - FS4")
        "AWS Group"             = @("CTX - AWS - APP - Dynamics GP")
        "Great Plains (GP)"     = @("Dynamics GP Users")
        "Cognos"                = @("CTX - Cognos TM1 - FS1","CTX - Cognos TM1 - FS4","CTX - IBM Cognos TM1 Client","Zscaler-ZPA-Cognos")
        "OMS"                   = @("OMSV30","OMSV30DEV")
        "M5"                    = @("M5 CA Users","M5 US Users")
        "Citrix Desktop (Temp)" = @("CTX - FS1 Temporary Desktop Access","CTX - FS4 Temporary Desktop Access","CTX - IT Desktop Users")
    }

    Write-Host ""
    Write-Host " GROUP CATEGORIES"
    Write-Host " ────────────────"
    $sections = @($GroupSections.Keys)
    for ($i = 0; $i -lt $sections.Count; $i++) {
        Write-Host " [$($i + 1)] $($sections[$i])"
    }

    $sectionChoice = Read-Host "`nSelect Category Number"

    # FIXED VALIDATION
    if ([string]::IsNullOrWhiteSpace($sectionChoice) -or
        -not ($sectionChoice -match '^\d+$') -or
        [int]$sectionChoice -lt 1 -or
        [int]$sectionChoice -gt $sections.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        Pause
        return
    }

    # FIXED INDEX ACCESS
    $selectedCategory = $sections[[int]$sectionChoice - 1]
    $groups = $GroupSections[$selectedCategory]

    Write-Header "AVAILABLE GROUPS"

    for ($i = 0; $i -lt $groups.Count; $i++) {

        $groupName = $groups[$i]

        Write-Host -NoNewline " [$($i + 1)] $groupName"

        if ($currentGroups -contains $groupName) {
            Write-Host " (Already a Member of)" -ForegroundColor Green
        }
        else {
            Write-Host ""
        }
    }

    $groupChoice = Read-Host "`nEnter group number(s) (comma separated)"

    $selectedGroups = $groupChoice -split "," |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d+$' -and $_ -ge 1 -and $_ -le $groups.Count } |
        ForEach-Object { $groups[$_ - 1] }

    if ($selectedGroups.Count -eq 0) {
        Write-Host "No valid groups selected." -ForegroundColor Red
        Pause
        return
    }

    Write-Header "ADDING GROUPS"

    foreach ($group in $selectedGroups) {

        if ($currentGroups -contains $group) {
            Write-Host "Skipped (Already a member): $group" -ForegroundColor Yellow
            continue
        }

        try {
            Add-ADGroupMember -Identity $group -Members $user.DistinguishedName -ErrorAction Stop
            Write-Host "Added $($user.SamAccountName) to $group" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to add $($user.SamAccountName) to $group" -ForegroundColor Red
        }
    }

    Pause
}

# ============================================================
# Sub-Menu - OPTION 4 – MANUALLY ADD GROUP
# ============================================================

function Add-GroupsManually {
    Clear-Host
    Write-Header "MANUALLY ADD AD GROUPS"

    $input = Read-Host "Enter Username or Full Name"

    try {
        # Try exact username
        $user = Get-ADUser -Filter "SamAccountName -eq '$input'" -ErrorAction SilentlyContinue

        # Fallback to name search
        if (-not $user) {
            $users = Get-ADUser -Filter "
                Name -like '*$input*' -or
                DisplayName -like '*$input*' -or
                GivenName -like '*$input*' -or
                Surname -like '*$input*'
            " -Properties DisplayName, SamAccountName

            if (-not $users) { throw }

            $users = @($users)

            if ($users.Count -gt 1) {
                Write-Header "MULTIPLE USERS FOUND"
                for ($i = 0; $i -lt $users.Count; $i++) {
                    Write-Host " [$($i + 1)] $($users[$i].DisplayName) ($($users[$i].SamAccountName))"
                }

                $choice = Read-Host "`nSelect user number"
                if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt $users.Count) {
                    throw
                }

                $user = $users[$choice - 1]
            }
            else {
                $user = $users[0]
            }
        }
    }
    catch {
        Write-Host "User not found or invalid selection." -ForegroundColor Red
        Pause
        return
    }

    Write-Header "TARGET USER"
    Write-Host " Full Name : $($user.DisplayName)"
    Write-Host " Username  : $($user.SamAccountName)"

    Write-Host ""
    Write-Host "Paste group names below:"
    Write-Host "• One group per line (Press Enter) OR comma-separated"
    Write-Host ""

    $rawGroups = @()
    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $rawGroups += $line
    }

    $groupNames = $rawGroups -join "," -split "," |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Sort-Object -Unique

    if ($groupNames.Count -eq 0) {
        Write-Host "No groups entered." -ForegroundColor Red
        Pause
        return
    }

    # Cache user memberships ONCE
    $currentGroups = Get-ADPrincipalGroupMembership -Identity $user |
                     Select-Object -ExpandProperty Name

    Write-Header "ADDING GROUPS"

    foreach ($groupName in $groupNames) {
        try {
            # SAFE group lookup by Name
            $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction Stop

            if ($currentGroups -contains $group.Name) {
                Write-Host "Already member of $groupName" -ForegroundColor Yellow
                continue
            }

            Add-ADGroupMember -Identity $group.DistinguishedName `
                              -Members $user.DistinguishedName `
                              -ErrorAction Stop

            Write-Host "Added $($user.SamAccountName) to $groupName" -ForegroundColor Green
        }
        catch {
            Write-Host "FAILED: Group not found or access denied → $groupName" -ForegroundColor Red
        }
    }

    Pause
}


# ============================================================
# Sub-Menu - OPTION 5 – REMOVE AD GROUPS
# ============================================================
function Remove-GroupsFromUser {
    Clear-Host
    Write-Header "REMOVE ACTIVE DIRECTORY GROUPS"
    
    $input = Read-Host "Enter Username or Full Name"
    $input = $input.Trim()
    
    try {
        # Try exact username first
        $users = Get-ADUser -Filter "SamAccountName -eq '$input'" -Properties DisplayName, Enabled -ErrorAction SilentlyContinue
        
        # Fallback to name search
        if (-not $users) {
            $users = Get-ADUser -Filter "
                Name -like '*$input*' -or
                DisplayName -like '*$input*' -or
                GivenName -like '*$input*' -or
                Surname -like '*$input*'
            " -Properties DisplayName, SamAccountName, Enabled
        }
        
        if (-not $users) { throw }
        
        $users = @($users)
        
        if ($users.Count -gt 1) {
            Write-Header "MULTIPLE USERS FOUND"
            for ($i = 0; $i -lt $users.Count; $i++) {
                Write-Host " [$($i + 1)] $($users[$i].DisplayName) ($($users[$i].SamAccountName))"
            }
            $choice = Read-Host "`nSelect user number"
            if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt $users.Count) {
                throw
            }
            $user = $users[$choice - 1]
        }
        else {
            $user = $users[0]
        }
        
        # Refresh full object
        $user = Get-ADUser $user.SamAccountName -Properties DisplayName, Enabled -ErrorAction Stop
    }
    catch {
        Write-Host "User not found or invalid selection." -ForegroundColor Red
        Pause
        return
    }
    
    Write-Header "REMOVE GROUPS FROM USER"
    Write-Host ""
    Write-Host " Full Name : $($user.DisplayName)"
    Write-Host " Username  : $($user.SamAccountName)"
    Write-Host ""
    
    $groups = Get-ADPrincipalGroupMembership -Identity $user | Sort-Object Name
    
    Write-Header "CURRENT GROUP MEMBERSHIPS"
    for ($i = 0; $i -lt $groups.Count; $i++) { 
        $groupName = $groups[$i].Name
        if ($groupName -in @("Domain Users", "Low Risk Users")) {
            Write-Host " [$($i + 1)] $groupName" -ForegroundColor Green
        }
        else {
            Write-Host " [$($i + 1)] $groupName"
        }
    }
    
    Write-Host ""
    $choice = Read-Host "Enter group number(s) to remove (comma separated)"
    
    # FIXED: Multiple group selection with comma separation
    $selectedGroups = $choice -split "," |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d+$' -and [int]$_ -ge 1 -and [int]$_ -le $groups.Count } |
        ForEach-Object { $groups[[int]$_ - 1] }
    
    if ($selectedGroups.Count -eq 0) {
        Write-Host "No valid groups selected." -ForegroundColor Red
        Pause
        return
    }
    
    Write-Header "REMOVING GROUPS"
    foreach ($group in $selectedGroups) {
        try {
            Remove-ADGroupMember -Identity $group -Members $user.SamAccountName -Confirm:$false -ErrorAction Stop
            Write-Host "Removed $($user.SamAccountName) from $($group.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove from $($group.Name)" -ForegroundColor Red
        }
    }
    
    Pause
}

# ============================================================
# OPTION 5 – LAPS PASSWORD + EXPIRE FEATURE
# ============================================================

function Get-LAPSPassword {
    Clear-Host
    Write-Header "LAPS PASSWORD RETRIEVAL"

    $computer = Read-Host "Enter Computer Name"

    try {
        $laps = Get-LapsADPassword -Identity $computer

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($laps.Password)
        $pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        Write-Host ""
        Write-Host " Computer Name : $computer"
        Write-Host " Password      : $pwd" -ForegroundColor Green
        Write-Host " Expiration    : $($laps.PasswordExpirationTimestamp)"
    }
    catch {
        Write-Host "LAPS password not found." -ForegroundColor Red
        Pause
        return
    }

    Write-Host ""
    Write-Host " [1] Expire LAPS Password (Force Reset)"
    Write-Host ""
    $choice = Read-Host "Select option"

    if ($choice -eq "1") {
        try {
            Set-ADComputer -Identity $computer `
                -Replace @{"ms-Mcs-AdmPwdExpirationTime" = 0} `
                -ErrorAction Stop

            Write-Host ""
            Write-Host "LAPS password expiration forced successfully." -ForegroundColor Green
            Write-Host "New password will be set when the machine checks in." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to expire LAPS password." -ForegroundColor Red
            Write-Host $_ -ForegroundColor DarkGray
        }

        Pause
    }
}


# ============================================================
# APPLICATION LOOP
# ============================================================

do {
    Show-MainMenu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1"  { Search-User }
        "2"  { Search-ByEmployeeID }
        "3"  { Search-ByPrinterCardID }
        
        "4"  { Show-GroupManagementMenu }
        
        "5"  { Get-LAPSPassword }
                      
        "0"  { break }
        default {
            Write-Host "Invalid option." -ForegroundColor Red
            Pause
        }
    }
}
while ($true)

