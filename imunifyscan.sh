#!/bin/bash

# Telegram Bot Token and Chat ID
TELEGRAM_BOT_TOKEN="TOKEN_HERE"
TELEGRAM_CHAT_ID="CHAT_ID_HERE"

# Email Notification Settings
EMAIL_RECIPIENT="Youremail@example.com"

# Initialize variables
init_data() {
        data=$(cat)     # Read the payload from stdin

        # Save payload for debugging
        echo "$data" > /tmp/imunify-script-dump.json

        # Extract event ID
        event_id=$(jq -r '.event_id' <<< "$data")

        # Extract user information, fallback to extracting from path if undefined
        user=$(jq -r '.initiator' <<< "$data")
        if [[ "$user" == "undefined" || -z "$user" ]]; then
                user=$(jq -r '.path' <<< "$data" | awk -F'/' '{print $NF}')
        fi
}

# Parse malware found data
parser_malware_found() {
        malicious_total=$(jq -r '.total_malicious // 0' <<< "$data")
        # Extract all malicious files as a comma-separated list
        malicious_files=$(jq -r '.malicious_files[] // "None"' <<< "$data" | tr '\n' ', ' | sed 's/, $//')
}

# Parse scan started data
parser_scan_started() {
        path=$(jq -r '.path // "Unknown"' <<< "$data")
}

# Send Telegram notification
send_telegram() {
        msg="$1"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$msg" > /dev/null
}

# Send Email notification
send_email() {
        subject="$1"
        body="$2"
        echo -e "To: $EMAIL_RECIPIENT\nSubject: $subject\n\n$body" | sendmail -t
}

# Process the payload and send notifications
payload_handler() {
        case $event_id in
                USER_SCAN_MALWARE_FOUND)
                        parser_malware_found
                        event_msg="⚠️ Malware detected by $user on $(hostname). Total: $malicious_total. Files: $malicious_files"
                        send_telegram "$event_msg"
                        send_email "Malware Alert on $(hostname)" "$event_msg"
                        ;;
                USER_SCAN_STARTED)
                        parser_scan_started
                        event_msg="✅ Scan started by $user on $(hostname). Path: $path"
                        send_telegram "$event_msg"
                        send_email "Scan Started on $(hostname)" "$event_msg"
                        ;;
                *)
                        echo "Unhandled event: $event_id" 1>&2
                        exit 1
                        ;;
        esac
}

# Initialize and handle payload
init_data
payload_handler
