# ImunifyAV Webmin Module

## Overview
The **ImunifyAV Webmin Module** provides seamless integration of the ImunifyAV(+) standalone UI into Webmin, allowing you to manage ImunifyAV directly from Webmin.

### Key Features:
- **UI Integration**: Secure iframe integration of the ImunifyAV(+) UI directly into Webmin.
- **Enhanced Security**: Access restricted to the root IP for added security.
- **Token-Based Login**: No credentials needed! The module uses ImunifyAV's token-based authentication, which refreshes on every reload.

---

## Installation ImunifyAV(+)

### Prerequisites
1. Install the standalone version of ImunifyAV by following the official guide:  
   [ImunifyAV Standalone Documentation](https://docs.imunify360.com/imunifyav/stand_alone_mode/).

2. **Set up the Configuration File**  
   Before starting the installation, create or update the following configuration file:  
   ```
   /etc/sysconfig/imunify360/integration.conf
   ```  
   Example configuration:  
   ```ini
   [paths]
   # Path where the ImunifyAV UI files will be installed and served
   ui_path = /home/._default_hostname/public_html/imunifyav

   # Ownership for UI files
   ui_path_owner = _default_hostname:_default_hostname

   [pam]
   # PAM service for user authentication
   service_name = system-auth
   ```

3. **Ensure a Valid Hostname**  
   Your server must have a valid hostname pointing to the UI installation path:  
   ```
   /home/._default_hostname/public_html/imunifyav
   ```

4. **Install ImunifyAV**  
   Run the following commands to install ImunifyAV:  
   ```bash
   wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh -O imav-deploy.sh
   bash imav-deploy.sh
   ```

---

### Module Installation
1. Download the module:  
   [imunify360.wbm.gz](https://github.com/iq-hosting/imunifyav-webmin-module/releases/download/v1.0.0/imunify360.wbm.gz)

2. Open Webmin:
   - Navigate to **Webmin Configuration > Webmin Modules**.
   - Select **From uploaded file** and upload the `.wbm.gz` file.

3. Click **Install Module**.

4. Navigate to the installed module in Webmin to start managing ImunifyAV.

---

## Notifications

The module includes support for notifications via **Telegram** and **Email** for the following events:
- **User scan: started**
- **Custom scan: started**
- **Custom scan: malware detected**
- **User scan: malware detected**

### Setup Instructions

1. **Edit the Notification Script**
   Open the Perl script located at:
   ```
   /usr/libexec/webmin/imunify360/imunifyscan.pl
   ```

2. **Update Configuration Variables**
   Inside the script, update the following settings to match your environment:
   - **Telegram Notifications:**
     ```perl
     my $telegram_bot_token = "YOUR_BOT_TOKEN_HERE";
     my $telegram_chat_id = "YOUR_CHAT_ID_HERE";
     ```
   - **Email Notifications:**
     ```perl
     my $email_recipient = 'your_email@example.com';
     ```
   - To disable Telegram or Email notifications, set the following variables:
     ```perl
     my $enable_telegram = 0; # Disable Telegram notifications
     my $enable_email = 0;    # Disable Email notifications
     ```

3. **Dependencies**
   Ensure that the following dependencies are installed:
   - **Perl Modules:**
     Install required modules for JSON parsing and HTTP requests:
     ```
     cpan JSON LWP::UserAgent
     ```
   - **Postfix Mail Server:**
     Make sure Postfix or a compatible mail server is installed and configured for Email notifications.

4. **Add the Script to Event Handlers**
   Configure the following events to trigger the notification script:
   ```
   User scan: started
   Custom scan: started
   Custom scan: malware detected
   User scan: malware detected
   ```

   Set the handler path to:
   ```
   /usr/libexec/webmin/imunify360/imunifyscan.pl
   ```

### Screenshot of Notification Settings
![Notifications Screenshot](https://github.com/iq-hosting/imunifyav-webmin-module/blob/main/Notifications.jpg?raw=true)

---


## Feedback Welcomed
This is version 1 of the module, and your feedback is invaluable! Let me know if there’s anything to improve or adjust. 

