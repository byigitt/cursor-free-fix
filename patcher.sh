#!/usr/bin/env bash

# Exit on error
set -e

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    # Check for perl
    if ! command -v perl >/dev/null 2>&1; then
        missing_deps+=("perl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies:"
        printf '  - %s\n' "${missing_deps[@]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "  - For Debian/Ubuntu: sudo apt-get install ${missing_deps[*]}"
        echo "  - For macOS: brew install ${missing_deps[*]}"
        echo "  - For other distributions, use your package manager"
        exit 1
    fi
}

# Check if running with sudo/root when needed
check_permissions() {
    local file="$1"
    if [ -f "$file" ] && [ ! -w "$file" ]; then
        echo "Error: No write permission for $file"
        echo "Please run the script with sudo or as root"
        exit 1
    fi
}

# Trap errors
trap 'echo "Error: Script failed on line $LINENO"' ERR

# Run dependency check
check_dependencies

# Colors for console output
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[96m'
PURPLE='\033[95m'
RESET='\033[0m'
REVERSE='\033[7m'
NO_REVERSE='\033[27m'

echo -e "
        ${RED}.:: ${PURPLE}[${RESET}Cursor Free Fix${PURPLE}]${RED} ::.${RESET}
            ${BLUE}Developed by${RESET} byigitt
         ${BLUE}Based on work by${RESET} zetaloop

${YELLOW}>${RESET} A tool to customize your Cursor IDE instance
${YELLOW}>${RESET} Configure machine ID and identifiers below:"

# Helper Functions
get_random_uuid() {
    python3 -c "import uuid; print(str(uuid.uuid4()))" || {
        echo -e "${RED}[ERR] Failed to generate UUID${RESET}"
        exit 1
    }
}

get_random_mac() {
    local mac=""
    while [[ -z "$mac" ]] || [[ "$mac" == "00:00:00:00:00:00" ]] || [[ "$mac" == "ff:ff:ff:ff:ff:ff" ]] || [[ "$mac" == "ac:de:48:00:11:22" ]]; do
        mac=$(printf '%02X:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    done
    echo "$mac"
}

get_default_js_path() {
    local os_type=$(uname -s)
    if [[ "$os_type" == "Darwin" ]]; then
        echo "/Applications/Cursor.app/Contents/Resources/app/out/main.js"
    else  # Linux
        for path in "/opt/Cursor/resources/app/out/main.js" "/usr/share/cursor/resources/app/out/main.js"; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return
            fi
        done
        echo -e "${RED}[ERR] Cursor IDE not found in default locations${RESET}"
        echo -e "${YELLOW}Please make sure Cursor IDE is installed or provide a custom path${RESET}"
        exit 1
    fi
}

# Get main.js path
echo -en "\n${PURPLE}Enter main.js path: ${RESET}(leave blank to use default path) "
read js_path

if [[ -z "$js_path" ]]; then
    js_path=$(get_default_js_path)
    if [[ -z "$js_path" ]] || [[ ! -f "$js_path" ]]; then
        echo -e "${RED}[ERR] main.js not found in default path '$js_path'${RESET}"
        read -p "Press Enter to continue..."
        exit 1
    fi
    echo -e "${GREEN}[√]${RESET} $js_path"
else
    js_path=$(realpath "$js_path" 2>/dev/null || echo "$js_path")
    if [[ ! -f "$js_path" ]]; then
        echo -e "${RED}[ERR] File '$js_path' not found${RESET}"
        read -p "Press Enter to continue..."
        exit 1
    fi
fi

# Check file permissions
check_permissions "$js_path"

# Backup the file
backup_path="${js_path}.bak"
echo -e "\n> Backing up '$js_path'"
if [[ ! -f "$backup_path" ]]; then
    if ! cp "$js_path" "$backup_path" 2>/dev/null; then
        echo -e "${RED}[ERR] Failed to create backup${RESET}"
        echo -e "${YELLOW}Try running with sudo${RESET}"
        exit 1
    fi
    echo -e "${GREEN}[√] Backup created: '$backup_path'${RESET}"
else
    echo -e "${BLUE}[i] Backup already exists, good${RESET}"
fi

# Read the file content
if ! content=$(<"$js_path"); then
    echo -e "${RED}[ERR] Failed to read file${RESET}"
    exit 1
fi

# Get MachineId
echo -en "\n${PURPLE}MachineId: ${RESET}(leave blank = random uuid) "
read machine_id
if [[ -z "$machine_id" ]]; then
    machine_id=$(get_random_uuid)
    echo "$machine_id"
fi

# Get MAC Address
echo -en "\n${PURPLE}Mac Address: ${RESET}(leave blank = random mac) "
read mac_address
if [[ -z "$mac_address" ]]; then
    mac_address=$(get_random_mac)
    echo "$mac_address"
fi

# Get Windows SQM ID
echo -en "\n${PURPLE}Windows SQM Id: ${RESET}(leave blank = empty) "
read sqm_id

# Get Device ID
echo -en "\n${PURPLE}devDeviceId: ${RESET}(leave blank = random uuid) "
read device_id
if [[ -z "$device_id" ]]; then
    device_id=$(get_random_uuid)
    echo "$device_id"
fi

# Function to apply pattern replacement
apply_pattern() {
    local name="$1"
    local pattern="$2"
    local replacement="$3"
    local probe="$4"
    
    echo -e "\n> Processing $name..."
    
    if echo "$content" | grep -qP "$pattern"; then
        content=$(echo "$content" | perl -pe "s/$pattern/$replacement/g")
        echo -e "${GREEN}[√] Pattern replaced successfully${RESET}"
        return 0
    elif echo "$content" | grep -qP "$probe"; then
        content=$(echo "$content" | perl -pe "s/$probe/$replacement/g")
        echo -e "${BLUE}[i] Found already patched pattern, updated${RESET}"
        return 0
    else
        echo -e "${YELLOW}[WARN] Pattern not found, SKIPPED!${RESET}"
        return 1
    fi
}

# Apply patches
patch_count=0

# MachineId
apply_pattern "MachineId" \
    "=.{0,50}timeout.{0,10}5e3.*?," \
    "=\/*csp1\*\/\"$machine_id\"\/\*1csp\*\/," \
    "\/\*csp1\*\/.*?\/\*1csp\*\/," && ((patch_count++))

# MacAddress
apply_pattern "MacAddress" \
    "(function .{0,50}\{).{0,300}Unable to retrieve mac address.*?(\})" \
    "\$1return\/*csp2\*\/\"$mac_address\"\/\*2csp\*\/;\$2" \
    "()return\/\*csp2\*\/.*?\/\*2csp\*\/;()" && ((patch_count++))

# SqmId
apply_pattern "SqmId" \
    "return.{0,50}\.GetStringRegKey.*?HKEY_LOCAL_MACHINE.*?MachineId.*?\|\|.*?\"\"" \
    "\/*csp3\*\/\"$sqm_id\"\/\*3csp\*\/" \
    "\/\*csp3\*\/.*?\/\*3csp\*\/" && ((patch_count++))

# DeviceId
apply_pattern "DeviceId" \
    "return.{0,50}vscode\/deviceid.*?getDeviceId\(\)" \
    "return\/*csp4\*\/\"$device_id\"\/\*4csp\*\/" \
    "return\/\*csp4\*\/.*?\/\*4csp\*\/" && ((patch_count++))

if [[ $patch_count -eq 0 ]]; then
    echo -e "\n${RED}[ERR] No patterns were matched or replaced${RESET}"
    echo -e "${YELLOW}This might indicate that the file structure has changed${RESET}"
    echo -e "${BLUE}[i] Your backup file is safe at: $backup_path${RESET}"
    read -p "Press Enter to continue..."
    exit 1
fi

# Save the changes
echo -e "\n> Saving changes to $js_path"
if ! echo "$content" > "$js_path" 2>/dev/null; then
    echo -e "${RED}[ERR] Failed to save file${RESET}"
    echo -e "${YELLOW}Try running the script with sudo or check file permissions${RESET}"
    if [[ -f "$backup_path" ]]; then
        echo -e "${BLUE}[i] You can restore the backup file manually from: $backup_path${RESET}"
    fi
    read -p "Press Enter to continue..."
    exit 1
fi

echo -e "${GREEN}[√] File saved successfully${RESET}"
echo -e "\n${GREEN}[√] All operations completed successfully!${RESET}"
echo -e "${BLUE}[i] If you need to restore the backup, it's located at: $backup_path${RESET}"
echo -e "\n${REVERSE}Press Enter to continue...${NO_REVERSE}"
read 