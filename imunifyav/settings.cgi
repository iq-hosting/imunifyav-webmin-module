#!/usr/bin/perl
#
# ImunifyAV Webmin Module - Notification Settings
# Configure Telegram and Email notifications for scan events
# Manage ImunifyAV event hooks
#

require './imunifyav-lib.pl';

use HTML::Entities;

# Initialize Webmin and parse parameters
&ReadParse();
&error_setup($text{'error_title'});

# Check module access permissions
my %access = &get_module_acl();
if (!$access{'full'}) {
    &error($text{'acl_denied'});
}

my $action = $in{'action'} || '';
$action = &sanitize_input($action, 'alphanum');

my $saved = 0;
my $hooks_installed = 0;
my $hooks_removed = 0;
my $error_message = '';
my $info_message = '';

# Process actions
if ($action eq 'save_settings') {
    # Validate and sanitize all inputs
    my $enable_telegram = $in{'enable_telegram'} ? 1 : 0;
    my $enable_email = $in{'enable_email'} ? 1 : 0;
    
    # Sanitize Telegram settings
    my $telegram_token = $in{'telegram_bot_token'} || '';
    $telegram_token = &sanitize_input($telegram_token, 'token');
    
    my $telegram_chat = $in{'telegram_chat_id'} || '';
    $telegram_chat = &sanitize_input($telegram_chat, 'chatid');
    
    # Sanitize and validate email
    my $email = $in{'email_recipient'} || '';
    $email = &sanitize_input($email, 'email');
    
    # Validate Telegram token format if enabled
    if ($enable_telegram && $telegram_token) {
        if ($telegram_token !~ /^[0-9]+:[a-zA-Z0-9_\-]+$/) {
            $error_message = $text{'settings_invalid_token'};
        }
    }
    
    # Validate email format if enabled
    if ($enable_email && $email && !$error_message) {
        if (!&validate_email($email)) {
            $error_message = $text{'settings_invalid_email'};
        }
    }
    
    # Save if no errors
    if (!$error_message) {
        my %new_config = (
            'enable_telegram' => $enable_telegram,
            'telegram_bot_token' => $telegram_token,
            'telegram_chat_id' => $telegram_chat,
            'enable_email' => $enable_email,
            'email_recipient' => $email
        );
        
        &save_notification_config(\%new_config);
        
        # Log the action (without sensitive data)
        my %log_data = (
            'enable_telegram' => $enable_telegram,
            'enable_email' => $enable_email,
            'has_token' => $telegram_token ? 1 : 0,
            'has_email' => $email ? 1 : 0
        );
        
        &webmin_log("save", "notifications", undef, \%log_data);
        &log_action("Notification settings saved");
        
        $saved = 1;
    }
}
elsif ($action eq 'install_hooks') {
    if (&install_hooks()) {
        # Restart ImunifyAV service automatically
        my $restart_result = system("systemctl", "restart", "imunify-antivirus");
        if ($restart_result == 0) {
            $hooks_installed = 1;
            &log_action("ImunifyAV hooks enabled and service restarted");
            &webmin_log("enable", "hooks");
        } else {
            $hooks_installed = 1;
            $info_message = $text{'settings_hooks_restart_failed'};
            &log_action("ImunifyAV hooks enabled but service restart failed");
            &webmin_log("enable", "hooks");
        }
    } else {
        $error_message = $text{'settings_hooks_install_failed'};
    }
}
elsif ($action eq 'remove_hooks') {
    if (&remove_hooks()) {
        # Restart ImunifyAV service automatically
        system("systemctl", "restart", "imunify-antivirus");
        $hooks_removed = 1;
        &log_action("ImunifyAV hooks disabled and service restarted");
        &webmin_log("disable", "hooks");
    } else {
        $error_message = $text{'settings_hooks_remove_failed'};
    }
}

# Read current configuration
my %config = &read_notification_config();
my $hooks_status = &check_hooks_installed();

# Print page header
&ui_print_header(undef, $text{'settings_title'}, "", undef, 1, 1);

# Use absolute path for CSS
my $css_path = "$gconfig{'webprefix'}/$module_name/style.css";
print "<link rel='stylesheet' href='$css_path'>\n";

# Navigation tabs
print "<div class='imunify360-tabs'>\n";
print "<a href='index.cgi' class='imunify360-tab'>" . &html_escape($text{'index_dashboard'}) . "</a>\n";
print "<a href='settings.cgi' class='imunify360-tab active'>" . &html_escape($text{'settings_title'}) . "</a>\n";
print "</div>\n";

# Show messages
if ($saved) {
    print "<div class='success-message'>\n";
    print "<strong>" . &html_escape($text{'settings_saved'}) . "</strong>\n";
    print "</div>\n";
}

if ($hooks_installed) {
    print "<div class='success-message'>\n";
    print "<strong>" . &html_escape($text{'settings_hooks_installed'}) . "</strong>\n";
    print "</div>\n";
}

if ($hooks_removed) {
    print "<div class='success-message'>\n";
    print "<strong>" . &html_escape($text{'settings_hooks_removed'}) . "</strong>\n";
    print "</div>\n";
}

if ($info_message) {
    print "<div class='info-message' style='background:#d1ecf1;color:#0c5460;padding:15px;border-radius:5px;margin:15px 0;border:1px solid #bee5eb;'>\n";
    print "<strong>" . &html_escape($info_message) . "</strong>\n";
    print "</div>\n";
}

if ($error_message) {
    print "<div class='error-message'>\n";
    print "<strong>" . &html_escape($error_message) . "</strong>\n";
    print "</div>\n";
}

# Event Hooks Section
print &ui_table_start($text{'settings_hooks'}, "width=100%", 2);

my $hooks_status_text = $hooks_status ? 
    "<span style='color:green;font-weight:bold;'>✓ " . &html_escape($text{'settings_hooks_active'}) . "</span>" :
    "<span style='color:red;font-weight:bold;'>✗ " . &html_escape($text{'settings_hooks_inactive'}) . "</span>";

print &ui_table_row($text{'settings_hooks_status'}, $hooks_status_text);

my $hooks_buttons = "";
if (!$hooks_status) {
    $hooks_buttons = &ui_form_start("settings.cgi", "post") .
        &ui_hidden("action", "install_hooks") .
        &ui_submit($text{'settings_hooks_install'}) .
        &ui_form_end();
} else {
    $hooks_buttons = &ui_form_start("settings.cgi", "post") .
        &ui_hidden("action", "remove_hooks") .
        &ui_submit($text{'settings_hooks_remove'}, undef, undef, undef, "onclick=\"return confirm('" . &html_escape($text{'settings_hooks_confirm_remove'}) . "')\"") .
        &ui_form_end();
}

print &ui_table_row($text{'settings_hooks_action'}, $hooks_buttons);

print &ui_table_row($text{'settings_hooks_info'},
    "<small>" . &html_escape($text{'settings_hooks_desc'}) . "</small>");

print &ui_table_end();

# Notification Settings form
print &ui_form_start("settings.cgi", "post");
print &ui_hidden("action", "save_settings");

# Telegram Settings Section
print &ui_table_start($text{'settings_telegram'}, "width=100%", 2);

print &ui_table_row($text{'settings_enable'},
    &ui_checkbox("enable_telegram", 1, "", $config{'enable_telegram'}));

print &ui_table_row($text{'settings_bot_token'},
    &ui_textbox("telegram_bot_token", $config{'telegram_bot_token'}, 60) .
    "<br><small>Format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz</small>");

print &ui_table_row($text{'settings_chat_id'},
    &ui_textbox("telegram_chat_id", $config{'telegram_chat_id'}, 25) .
    "<br><small>Format: -1001234567890 or 123456789</small>");

print &ui_table_end();

# Email Settings Section
print &ui_table_start($text{'settings_email'}, "width=100%", 2);

print &ui_table_row($text{'settings_enable'},
    &ui_checkbox("enable_email", 1, "", $config{'enable_email'}));

print &ui_table_row($text{'settings_recipient'},
    &ui_textbox("email_recipient", $config{'email_recipient'}, 50) .
    "<br><small>Format: admin\@example.com</small>");

print &ui_table_end();

# Submit button
print "<div style='text-align:center; margin-top:20px;'>\n";
print &ui_submit($text{'settings_save'});
print "</div>\n";

print &ui_form_end();

# Module Footer
print "<div style='text-align:center; margin-top:30px; padding:20px; border-top:1px solid #e0e0e0; color:#6c757d; font-size:13px;'>\n";
print "&copy; 2025 <a href='https://www.iq-hosting.com' target='_blank' style='color:#38ab63; text-decoration:none; font-weight:600;'>IQ Hosting</a> | ";
print "Community Module for ImunifyAV\n";
print "</div>\n";

# Print page footer
&ui_print_footer("index.cgi", $text{'index_title'});
