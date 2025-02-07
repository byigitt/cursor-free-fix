#!/usr/bin/env bash

# Exit on error
set -e

# Colors for console output
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[96m'
PURPLE='\033[95m'
RESET='\033[0m'
REVERSE='\033[7m'
NO_REVERSE='\033[27m'

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    else
        # Check Python version
        python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)" 2>/dev/null || {
            echo -e "${RED}Error: Python 3.6 or higher is required${RESET}"
            exit 1
        }

        # Check required Python modules
        python3 -c "import uuid, re" 2>/dev/null || {
            echo -e "${RED}Error: Missing required Python modules${RESET}"
            exit 1
        }
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
        if [ "$EUID" -eq 0 ]; then
            echo -e "${RED}Error: Cannot write to $file even with root privileges${RESET}"
            echo -e "${YELLOW}This might be due to System Integrity Protection (SIP) or other security measures${RESET}"
            echo -e "${YELLOW}Try closing Cursor IDE if it's running${RESET}"
        else
            echo -e "${RED}Error: No write permission for $file${RESET}"
            echo -e "${YELLOW}Please run the script with sudo or as root${RESET}"
        fi
        exit 1
    fi
}

# Get default js path based on OS
get_default_js_path() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "/Applications/Cursor.app/Contents/Resources/app/out/main.js"
    else  # Linux
        for path in "/opt/Cursor/resources/app/out/main.js" "/usr/share/cursor/resources/app/out/main.js"; do
            if [[ -f "$path" ]]; then
                echo "$path"
                return
            fi
        done
        echo ""
    fi
}

# Create Python script for pattern replacement
create_python_script() {
    cat > _replace.py << 'EOL'
import sys
import re
import random
from uuid import uuid4

def get_random_mac():
    while True:
        mac = ':'.join([f'{random.randint(0, 255):02X}' for _ in range(6)])
        if mac not in ('00:00:00:00:00:00', 'ff:ff:ff:ff:ff:ff', 'ac:de:48:00:11:22'):
            return mac

def replace(data, pattern, replace, probe):
    regex = re.compile(pattern, re.DOTALL)
    count = len(list(regex.finditer(data)))
    patched_regex = re.compile(probe, re.DOTALL)
    patched_count = len(list(patched_regex.finditer(data)))

    if count == 0 and patched_count == 0:
        print(f"\033[93m⚠ Pattern not found, SKIPPED!\033[0m")
        return data, False

    if count == 0 and patched_count > 0:
        print(f"\033[96mℹ Found already patched pattern, will update\033[0m")
    
    data = regex.sub(replace, data)
    data = patched_regex.sub(replace, data)
    print(f"\033[92m✓ Pattern replaced successfully\033[0m")
    return data, True

def main():
    js_path = sys.argv[1]
    machine_id = sys.argv[2] if len(sys.argv) > 2 else str(uuid4())
    mac_address = sys.argv[3] if len(sys.argv) > 3 else get_random_mac()
    sqm_id = sys.argv[4] if len(sys.argv) > 4 else ""
    device_id = sys.argv[5] if len(sys.argv) > 5 else str(uuid4())

    # Read file
    with open(js_path, 'r', encoding='utf-8') as f:
        content = f.read()

    patch_count = 0
    patterns = [
        ("MachineId", 
         r'=.{0,50}timeout.{0,10}5e3.*?,',
         f'=/*csp1*/"{machine_id}"/*1csp*/,',
         r'=/\*csp1\*/.*?/\*1csp\*/,'),
        
        ("MacAddress",
         r'(function .{0,50}\{).{0,300}Unable to retrieve mac address.*?(\})',
         f'\\1return/*csp2*/"{mac_address}"/*2csp*/;\\2',
         r'()return/\*csp2\*/.*?/\*2csp\*/;()'),
        
        ("SqmId",
         r'return.{0,50}\.GetStringRegKey.*?HKEY_LOCAL_MACHINE.*?MachineId.*?\|\|.*?""',
         f'/*csp3*/"{sqm_id}"/*3csp*/',
         r'/\*csp3\*/.*?/\*3csp\*/'),
        
        ("DeviceId",
         r'return.{0,50}vscode\/deviceid.*?getDeviceId\(\)',
         f'return/*csp4*/"{device_id}"/*4csp*/',
         r'return/\*csp4\*/.*?/\*4csp\*/')
    ]

    for name, pattern, replacement, probe in patterns:
        print(f"\n> Processing {name}...")
        content, success = replace(content, pattern, replacement, probe)
        if success:
            patch_count += 1

    if patch_count == 0:
        sys.exit(1)

    # Write changes
    with open(js_path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
EOL
}

# Trap errors
trap 'echo "Error: Script failed on line $LINENO"' ERR

# Run dependency check
check_dependencies

# Check for macOS and root privileges
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script needs sudo privileges on macOS to modify Cursor files.${RESET}"
        echo -e "${YELLOW}Please run with: sudo bash $0${RESET}"
        exit 1
    fi
fi

echo -e "
        ${RED}.:: ${PURPLE}[${RESET}Cursor Free Fix${PURPLE}]${RED} ::.${RESET}
            ${BLUE}Developed by${RESET} byigitt
         ${BLUE}Based on work by${RESET} zetaloop

${YELLOW}>${RESET} A tool to customize your Cursor IDE instance
${YELLOW}>${RESET} Configure machine ID and identifiers below:"

# Get main.js path from argument or prompt
if [ $# -eq 1 ]; then
    js_path="$1"
    js_path=$(realpath "$js_path" 2>/dev/null || echo "$js_path")
    if [[ ! -f "$js_path" ]]; then
        echo -e "${RED}Error: File '$js_path' not found${RESET}"
        exit 1
    fi
    echo -e "${GREEN}[√]${RESET} Using provided path: $js_path"
else
    echo -en "\n${PURPLE}Enter main.js path: ${RESET}(leave blank to use default path) "
    read js_path

    if [[ -z "$js_path" ]]; then
        js_path=$(get_default_js_path)
        if [[ -z "$js_path" ]] || [[ ! -f "$js_path" ]]; then
            echo -e "${RED}[ERR] Cursor IDE not found in default locations${RESET}"
            echo -e "${YELLOW}Please make sure Cursor IDE is installed or provide a custom path${RESET}"
            exit 1
        fi
        echo -e "${GREEN}[√]${RESET} $js_path"
    else
        js_path=$(realpath "$js_path" 2>/dev/null || echo "$js_path")
        if [[ ! -f "$js_path" ]]; then
            echo -e "${RED}[ERR] File '$js_path' not found${RESET}"
            exit 1
        fi
    fi
fi

# Check file permissions
check_permissions "$js_path"

# Get user input for values
echo -en "\n${PURPLE}MachineId: ${RESET}(leave blank = random uuid) "
read machine_id

echo -en "\n${PURPLE}Mac Address: ${RESET}(leave blank = random mac) "
read mac_address

echo -en "\n${PURPLE}Windows SQM Id: ${RESET}(leave blank = empty) "
read sqm_id

echo -en "\n${PURPLE}devDeviceId: ${RESET}(leave blank = random uuid) "
read device_id

# Create backup
backup_path="${js_path}.bak"
echo -e "\n> Creating backup of '$js_path'"
if [[ ! -f "$backup_path" ]]; then
    if ! cp "$js_path" "$backup_path" 2>/dev/null; then
        echo -e "${RED}[ERR] Failed to create backup${RESET}"
        exit 1
    fi
    echo -e "${GREEN}[√] Backup created: '$backup_path'${RESET}"
else
    echo -e "${BLUE}[i] Backup already exists, good${RESET}"
fi

# Create and run Python script
create_python_script

if ! python3 _replace.py "$js_path" "$machine_id" "$mac_address" "$sqm_id" "$device_id"; then
    echo -e "\n${RED}[ERR] No patterns were matched or replaced${RESET}"
    echo -e "${YELLOW}This might indicate that the file structure has changed${RESET}"
    echo -e "${BLUE}[i] Your backup file is safe at: $backup_path${RESET}"
    rm _replace.py
    exit 1
fi

# Clean up
rm _replace.py

echo -e "\n${GREEN}[√] All operations completed successfully!${RESET}"
echo -e "${BLUE}[i] If you need to restore the backup, it's located at: $backup_path${RESET}"
echo -e "\n${REVERSE}Press Enter to continue...${NO_REVERSE}"
read 