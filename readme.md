# Cursor Free Fix

A tool to patch Cursor's telemetry values (machine ID, MAC address, Windows SQM ID, device ID) to custom values. This script helps you customize your Cursor IDE instance by modifying the following identifiers:

- Machine ID: A unique identifier for your machine (random UUID by default)
- MAC Address: Your network interface's MAC address (random MAC by default)
- Windows SQM ID: Windows telemetry identifier (empty by default)
- Device ID: Device-specific identifier (random UUID by default)

The script automatically creates backups before making any changes and provides options to use either default or custom paths for the main.js file.

### Can be used when encountered with these messages

> ⚠️ **Warning**: Make sure to delete your account and create a new one before using this script to reset your fast request limit.

#### Issue 1: Trial Account Limit

```text
Too many free trial accounts used on this machine.
Please upgrade to pro. We have this limit in place
to prevent abuse. Please let us know if you believe
this is a mistake.
```

#### Issue 2: Trial Request Limit

```text
You've reached your trial request limit.
```

## Version Compatibility

This tool works with all versions of Cursor IDE, with special focus on:

- ✅ Works perfectly with version 0.45.x
- 🔄 If it doesn't work on old versions, try upgrading to 0.45.x
- 💡 Tested and confirmed working on multiple Cursor versions

> 📝 **Note**: If you encounter any issues with old versions, you can download v0.45.x from the [Cursor releases page](https://cursor.com/downloads/).

## Quick Start

> ⚠️ **Warning**: Always review the script's source code before executing it. Never run scripts directly from the internet without inspecting them first.

### Windows (PowerShell)

```powershell
irm cursor.baris.pw/win | iex
```

### macOS (Bash)

> ⚠️ **Note**: The script requires sudo privileges on macOS to modify Cursor app files.

```bash
sudo curl -sSL cursor.baris.pw/bash | sudo bash
```

### Linux (Bash)

```bash
curl -sSL cursor.baris.pw/bash | bash
```

## Preview

### Windows PowerShell

![Windows PowerShell Preview](images/win.png)
_Preview of Cursor Free Fix running on Windows PowerShell_

### Requirements

#### For Windows

- PowerShell 7+ (recommended) or Windows PowerShell 5.1+
- Cursor IDE installed

#### For Linux/Mac

- Bash shell
- Python 3.x (for UUID generation)
- Cursor IDE installed
- `perl` (usually pre-installed on most Unix-like systems)

### Manual Usage

#### Windows Users

1. Open PowerShell
2. Navigate to the script directory
3. Run the script:

```powershell
.\patcher.ps1
```

#### macOS Users

1. Open Terminal
2. Navigate to the script directory
3. Make the script executable:

```bash
chmod +x patcher.sh
```

4. Run the script with sudo:

```bash
sudo ./patcher.sh
```

#### Linux Users

1. Open Terminal
2. Navigate to the script directory
3. Make the script executable:

```bash
chmod +x patcher.sh
```

4. Run the script:

```bash
./patcher.sh
```

## Notes

- The script will create a backup of your `main.js` file before making any changes
- You can leave inputs blank to use random values
- The script will automatically detect the default Cursor installation path, but you can specify a custom path if needed

## Source Code

The source code is available on GitHub: [byigitt/cursor-free-fix](https://github.com/byigitt/cursor-free-fix)

## Credits

- [zetaloop](https://github.com/zetaloop) for the original script
