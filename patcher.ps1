# Cursor Shadow Patch for Windows
# Colors for console output
$RED = "`e[91m"
$GREEN = "`e[92m"
$YELLOW = "`e[93m"
$BLUE = "`e[96m"
$PURPLE = "`e[95m"
$RESET = "`e[0m"
$REVERSE = "`e[7m"
$NO_REVERSE = "`e[27m"

# Check PowerShell version and ANSI support
$PSVersionTable.PSVersion | Out-Null
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "${RED}Error: PowerShell 5.1 or higher is required.${RESET}"
    pause
    exit 1
}

# Try to enable ANSI support for older Windows versions
if ($PSVersionTable.PSVersion.Major -lt 7) {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $Host.UI.RawUI.WindowTitle = "Cursor Free Fix"
    } catch {
        # Ignore if it fails
    }
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "${YELLOW}Warning: Running without administrator privileges. Some operations might fail.${RESET}"
}

Write-Host @"

        $RED.:: $PURPLE[$RESET Cursor Free Fix $PURPLE]$RED ::.$RESET
           $BLUE Developed by$RESET byigitt
         $BLUE Based on work by$RESET zetaloop

$YELLOW>$RESET A tool to customize your Cursor IDE instance
$YELLOW>$RESET Configure machine ID and identifiers below:
"@

# Helper Functions
function Get-RandomUUID {
    return [guid]::NewGuid().ToString()
}

function Get-RandomMacAddress {
    $mac = (1..6 | ForEach-Object { '{0:X2}' -f (Get-Random -Minimum 0 -Maximum 255) }) -join ':'
    while ($mac -in @('00:00:00:00:00:00', 'ff:ff:ff:ff:ff:ff', 'ac:de:48:00:11:22')) {
        $mac = (1..6 | ForEach-Object { '{0:X2}' -f (Get-Random -Minimum 0 -Maximum 255) }) -join ':'
    }
    return $mac
}

function Get-DefaultJsPath {
    $localAppData = $env:LOCALAPPDATA
    if (-not $localAppData) {
        Write-Host "${RED}[ERR] LOCALAPPDATA environment variable not found${RESET}"
        pause
        exit 1
    }
    $jsPath = Join-Path $localAppData "Programs\cursor\resources\app\out\main.js"
    
    # Check if Cursor is installed
    if (-not (Test-Path $jsPath)) {
        Write-Host "${RED}[ERR] Cursor IDE not found in default location${RESET}"
        Write-Host "${YELLOW}Please make sure Cursor IDE is installed or provide a custom path${RESET}"
        pause
        exit 1
    }
    
    return $jsPath
}

# Get main.js path
Write-Host "`n${PURPLE}Enter main.js path: ${RESET}(leave blank to use default path) " -NoNewline
$jsPath = Read-Host

if (-not $jsPath) {
    try {
        $jsPath = Get-DefaultJsPath
        Write-Host "${GREEN}[√]${RESET} $jsPath"
    }
    catch {
        Write-Host "${RED}[ERR] Failed to get default path: $_${RESET}"
        pause
        exit 1
    }
}
else {
    try {
        $jsPath = Resolve-Path $jsPath -ErrorAction Stop
        if (-not (Test-Path $jsPath)) {
            Write-Host "${RED}[ERR] File '$jsPath' not found${RESET}"
            pause
            exit 1
        }
    }
    catch {
        Write-Host "${RED}[ERR] Invalid path: $_${RESET}"
        pause
        exit 1
    }
}

# Check file access before proceeding
try {
    $testWrite = [System.IO.File]::OpenWrite($jsPath)
    $testWrite.Close()
}
catch {
    Write-Host "${RED}[ERR] Cannot write to file: $_${RESET}"
    Write-Host "${YELLOW}Try running the script as administrator${RESET}"
    pause
    exit 1
}

# Backup the file
$backupPath = "$jsPath.bak"
Write-Host "`n> Backing up '$jsPath'"
try {
    if (-not (Test-Path $backupPath)) {
        Copy-Item $jsPath $backupPath -ErrorAction Stop
        Write-Host "${GREEN}[√] Backup created: '$backupPath'${RESET}"
    }
    else {
        Write-Host "${BLUE}[i] Backup already exists, good${RESET}"
    }
}
catch {
    Write-Host "${RED}[ERR] Failed to create backup: $_${RESET}"
    pause
    exit 1
}

# Read the file content
try {
    $content = Get-Content $jsPath -Raw -ErrorAction Stop
}
catch {
    Write-Host "${RED}[ERR] Failed to read file: $_${RESET}"
    pause
    exit 1
}

# Get MachineId
Write-Host "`n${PURPLE}MachineId: ${RESET}(leave blank = random uuid) " -NoNewline
$machineId = Read-Host
if (-not $machineId) {
    $machineId = Get-RandomUUID
    Write-Host $machineId
}

# Get MAC Address
Write-Host "`n${PURPLE}Mac Address: ${RESET}(leave blank = random mac) " -NoNewline
$macAddress = Read-Host
if (-not $macAddress) {
    $macAddress = Get-RandomMacAddress
    Write-Host $macAddress
}

# Get Windows SQM ID
Write-Host "`n${PURPLE}Windows SQM Id: ${RESET}(leave blank = empty) " -NoNewline
$sqmId = Read-Host

# Get Device ID
Write-Host "`n${PURPLE}devDeviceId: ${RESET}(leave blank = random uuid) " -NoNewline
$deviceId = Read-Host
if (-not $deviceId) {
    $deviceId = Get-RandomUUID
    Write-Host $deviceId
}

# Apply patches
$patterns = @{
    MachineId = @{
        Pattern = '=.{0,50}timeout.{0,10}5e3.*?,'
        Replace = "=/*csp1*/`"$machineId`"/*1csp*/,"
        Probe = '/\*csp1\*/.*?/\*1csp\*/,'
    }
    MacAddress = @{
        Pattern = '(function .{0,50}\{).{0,300}Unable to retrieve mac address.*?(\})'
        Replace = "`$1return/*csp2*/`"$macAddress`"/*2csp*/;`$2"
        Probe = '()return/\*csp2\*/.*?/\*2csp\*/;()'
    }
    SqmId = @{
        Pattern = 'return.{0,50}\.GetStringRegKey.*?HKEY_LOCAL_MACHINE.*?MachineId.*?\|\|.*?""'
        Replace = "/*csp3*/`"$sqmId`"/*3csp*/"
        Probe = '/\*csp3\*/.*?/\*3csp\*/'
    }
    DeviceId = @{
        Pattern = 'return.{0,50}vscode\/deviceid.*?getDeviceId\(\)'
        Replace = "return/*csp4*/`"$deviceId`"/*4csp*/"
        Probe = 'return/\*csp4\*/.*?/\*4csp\*/'
    }
}

$patchCount = 0
foreach ($key in $patterns.Keys) {
    $pattern = $patterns[$key]
    Write-Host "`n> Processing $key..."
    
    if ($content -match $pattern.Pattern) {
        $content = $content -replace $pattern.Pattern, $pattern.Replace
        Write-Host "${GREEN}[√] Pattern replaced successfully${RESET}"
        $patchCount++
    }
    elseif ($content -match $pattern.Probe) {
        $content = $content -replace $pattern.Probe, $pattern.Replace
        Write-Host "${BLUE}[i] Found already patched pattern, updated${RESET}"
        $patchCount++
    }
    else {
        Write-Host "${YELLOW}[WARN] Pattern not found, SKIPPED!${RESET}"
    }
}

if ($patchCount -eq 0) {
    Write-Host "`n${RED}[ERR] No patterns were matched or replaced${RESET}"
    Write-Host "${YELLOW}This might indicate that the file structure has changed${RESET}"
    Write-Host "${BLUE}[i] Your backup file is safe at: $backupPath${RESET}"
    pause
    exit 1
}

# Save the changes
try {
    Write-Host "`n> Saving changes to $jsPath"
    $content | Set-Content $jsPath -NoNewline -ErrorAction Stop
    Write-Host "${GREEN}[√] File saved successfully${RESET}"
}
catch {
    Write-Host "${RED}[ERR] Failed to save file: $_${RESET}"
    Write-Host "${YELLOW}Try running the script as administrator or check file permissions${RESET}"
    if (Test-Path $backupPath) {
        Write-Host "${BLUE}[i] You can restore the backup file manually from: $backupPath${RESET}"
    }
    pause
    exit 1
}

Write-Host "`n${GREEN}[√] All operations completed successfully!${RESET}"
Write-Host "${BLUE}[i] If you need to restore the backup, it's located at: $backupPath${RESET}"
Write-Host "`n${REVERSE}Press Enter to continue...${NO_REVERSE}"
Read-Host 