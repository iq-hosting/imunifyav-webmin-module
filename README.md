# ImunifyAV Webmin Module

A Webmin module that provides seamless integration of ImunifyAV(+) standalone UI directly into Webmin.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Webmin](https://img.shields.io/badge/Webmin-1.460+-orange.svg)

## Features

- **Secure UI Integration** - Access ImunifyAV interface directly from Webmin via secure iframe
- **IP Restriction** - Automatic `.htaccess` updates to allow only the current root session IP
- **Token-Based Authentication** - Secure token-based login with automatic refresh on each page load
- **Notification System** - Telegram and Email alerts for malware detection and scan events
- **Automatic Event Hooks** - Enable/disable notifications with one click
- **Multi-language Support** - English and Arabic translations included

## Requirements

- Webmin 1.460 or later
- ImunifyAV(+) installed in standalone mode
- Apache web server with mod_rewrite
- Perl 5.8 or later
- Perl modules: `JSON`, `LWP::UserAgent` (for notifications)
- **Server hostname with SSL enabled**

## Installation

### Step 1: Install ImunifyAV (if not already installed)

**Important:** The `integration.conf` file must be created BEFORE installing ImunifyAV.

1. Create the configuration directory:

```bash
mkdir -p /etc/sysconfig/imunify360
```

2. Create the integration configuration file:

```bash
nano /etc/sysconfig/imunify360/integration.conf
```

3. Add the following configuration:

```ini
[paths]
ui_path = /home/._hostname/public_html/imunifyav
ui_path_owner = _hostname:_hostname

[pam]
service_name = system-auth
```

**Note:** Webmin automatically creates a user named `._hostname` when SSL is enabled for the hostname. In most cases, you can use the configuration exactly as shown above. The subdirectory name **must be `imunifyav`** - this module expects this exact path structure.

**Verify the correct path on your system:**
```bash
# Check if the hostname directory exists
ls -la /home/ | grep hostname

# Common paths:
# /home/._hostname/     (most common)
# /home/.hostname/      (some systems)
```

If your system uses a different naming convention, adjust the `ui_path` accordingly, but always keep the subdirectory as `/imunifyav`.

4. Install ImunifyAV:

```bash
wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh -O imav-deploy.sh
bash imav-deploy.sh
```

For detailed information, refer to the [official ImunifyAV documentation](https://docs.imunify360.com/imunifyav/stand_alone_mode/).

### Step 2: Install the Webmin Module

1. Download the latest release: [imunifyav.wbm.gz](https://github.com/iq-hosting/imunifyav-webmin-module/releases)

2. In Webmin, go to **Webmin → Webmin Configuration → Webmin Modules**

3. Select **From uploaded file** and upload `imunifyav.wbm.gz`

4. Click **Install Module**

5. Find "ImunifyAV Manager" under the **System** category

### Step 3: Enable Content-Security-Policy

On first access, you'll be prompted to enable CSP. Click **Enable CSP** to enhance security.

## Configuration

### Notification Settings

1. Open the module and click on **Notification Settings** tab

2. Configure Telegram notifications:
   - Enable Telegram
   - Enter your Bot Token (format: `123456789:ABCdefGHI...`)
   - Enter your Chat ID

3. Configure Email notifications:
   - Enable Email
   - Enter recipient email address

4. Click **Save Settings**

### Event Handler Setup

The module can automatically enable ImunifyAV event notifications:

1. Open the module and go to **Notification Settings** tab

2. In the **ImunifyAV Event Hooks** section, click **Enable Notifications**

3. The service will restart automatically. If restart fails, run manually:

```bash
systemctl restart imunify-antivirus
```

**To disable notifications:** Click **Disable Notifications** in the same section.

## Supported Events

- **USER_SCAN_STARTED** - When a user initiates a scan
- **USER_SCAN_MALWARE_FOUND** - When malware is detected in user scan
- **CUSTOM_SCAN_STARTED** - When a custom scan begins
- **CUSTOM_SCAN_MALWARE_FOUND** - When malware is found in custom scan

## Security Notes

- The module restricts UI access to the current root session IP only
- Authentication tokens are refreshed on each page load
- Input validation and sanitization on all user inputs
- CSP headers prevent XSS and clickjacking attacks
- All sensitive operations are logged for audit trails

## Log Files

- Module actions: `/var/log/imunifyav_webmin.log`
- Scan events: `/var/log/imunifyav_scan_events.log`

View logs:

```bash
tail -f /var/log/imunifyav_scan_events.log
```

## Troubleshooting

### Token Retrieval Failed

1. Verify your `ui_path` in `/etc/sysconfig/imunify360/integration.conf` matches the expected format:
   ```
   ui_path = /home/._hostname/public_html/imunifyav
   ```

2. The directory name **must be `imunifyav`** - the module cannot work with other names.

3. Verify ImunifyAV agent is working:
   ```bash
   imunify360-agent login get --username root
   ```

### Notifications Not Working

1. Check if the configuration file is readable:
   ```bash
   ls -la /usr/libexec/webmin/imunifyav/notifications.conf
   # Should show: -rw-r--r-- (644)
   ```

2. Test the script manually:
   ```bash
   echo '{"event_id":"USER_SCAN_STARTED","path":"/home/test"}' | /usr/libexec/webmin/imunifyav/imunifyscan.pl
   ```

3. Check the log:
   ```bash
   cat /var/log/imunifyav_scan_events.log
   ```

### Iframe Not Loading

1. Ensure your hostname resolves correctly
2. Check that SSL certificate is valid
3. Verify CSP is enabled in Webmin config

## Dependencies

### Required Perl Modules (for notifications)

```bash
# CentOS/RHEL
yum install perl-JSON perl-libwww-perl

# Debian/Ubuntu
apt install libjson-perl libwww-perl

# Or via CPAN
cpan JSON LWP::UserAgent
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Disclaimer

This module is a **community-developed integration** by **IQ Hosting** and is **not an official product** of CloudLinux / Imunify360.

## Author

**IQ Hosting** - [https://www.iq-hosting.com](https://www.iq-hosting.com)

---

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/iq-hosting/imunifyav-webmin-module/issues) page.