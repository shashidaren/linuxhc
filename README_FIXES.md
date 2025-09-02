# Linux Healthcheck Script - RHEL/Fedora Fixed Version

## Changes Made for RHEL/Fedora Compatibility

### Fixed Files:
- `checks/20_cpu.sh` - Separated `top -bn1` to `top -b -n 1`
- `checks/30_memory.sh` - Fixed awk quote escaping
- `checks/40_disk.sh` - Separated `df -Pi` to `df -P` and `df -i`
- `checks/45_fs_mounts.sh` - Fixed awk quote escaping
- `checks/70_updates.sh` - Prioritized dnf/yum, fixed grep options
- `checks/90_logs.sh` - Separated grep options, prioritized /var/log/messages
- `checks/95_hardware.sh` - Separated `lsblk -ndo` to `lsblk -n -d -o`

### Key Fixes:
1. **Command Option Separation**: Split combined short options (e.g., `-bn1` → `-b -n 1`)
2. **Quote Escaping**: Fixed awk commands with proper escaping for bash -lc execution
3. **RHEL/Fedora Priority**: Prioritized dnf/yum over apt, /var/log/messages over syslog
4. **Compatibility**: Ensured commands work on older versions found in RHEL/CentOS

### Usage:
```bash
./healthcheck.sh -h                    # Show help
./healthcheck.sh                       # Check localhost
./healthcheck.sh -s server1.example.com  # Check remote server
./healthcheck.sh -f servers.txt        # Check multiple servers from file
./healthcheck.sh -o json               # JSON output format
```

### Tested On:
- RHEL 8/9
- CentOS 8/9
- Fedora 35+
- Rocky Linux 8/9

Date: 2025-09-02
