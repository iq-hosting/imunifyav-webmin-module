# ImunifyAV Webmin Module

## Overview
The **ImunifyAV Webmin Module** provides seamless integration of the ImunifyAV(+) standalone UI into Webmin, allowing you to manage ImunifyAV directly from Webmin with zero code edits.

### Key Features:
- **Zero Code Edits**: Ready to use out of the box!
- **UI Integration**: Secure iframe integration of the ImunifyAV(+) UI directly into Webmin.
- **Enhanced Security**: Access restricted to the root IP for added security.
- **Token-Based Login**: No credentials needed! The module uses ImunifyAV's token-based authentication, which refreshes on every reload.

---

## Installation

### Prerequisites
1. Install the standalone version of ImunifyAV by following the official guide:  
   [ImunifyAV Standalone Documentation](https://docs.imunify360.com/imunifyav/stand_alone_mode/).

2. Before installation, update the configuration file:
   ```
   /etc/sysconfig/imunify360/integration.conf
   ```
   Example:
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

3. Ensure your server has a valid hostname. The module UI will be installed in the path:
   ```
   /home/._default_hostname/public_html/imunifyav
   ```

---

### Module Installation
1. Download the module:  
   [imunify360.wbm.gz](https://raw.githubusercontent.com/iq-hosting/imunifyav-webmin-module/main/imunify360.wbm.gz)

2. Open Webmin:
   - Navigate to **Webmin Configuration > Webmin Modules**.
   - Select **From uploaded file** and upload the `.wbm.gz` file.

3. Click **Install Module**.

4. Navigate to the installed module in Webmin to start managing ImunifyAV.

---

### Notifications

The module includes support for notifications via **Telegram** and **Email** for the following events:
- **User scan: started**
- **Custom scan: started**
- **Custom scan: malware detected**
- **User scan: malware detected**

#### Setup Instructions
1. Edit the notification script located at:
   ```
   /usr/libexec/webmin/imunify360/imunifyscan.sh
   ```
2. Update the following variables in the script:
   - `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` for Telegram notifications.
   - `EMAIL_RECIPIENT` for Email notifications.

3. Add the script to the desired event handlers to receive notifications.
![Notifications Screenshot](https://github.com/iq-hosting/imunifyav-webmin-module/blob/main/Notifications.jpg?raw=true)


## Feedback Welcomed
This is version 1 of the module, and your feedback is invaluable! Let me know if there’s anything to improve or adjust. 

