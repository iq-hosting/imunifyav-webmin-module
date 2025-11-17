#!/usr/bin/perl
#
# ImunifyAV Webmin Module - Main Dashboard
# Provides secure iframe integration with ImunifyAV standalone UI
#

require './imunifyav-lib.pl';

use Socket qw(AF_INET AF_INET6 inet_pton inet_ntop);
use HTML::Entities;
use URI::Escape qw(uri_escape);

# Initialize Webmin and parse parameters
&ReadParse();
&error_setup($text{'error_title'});

# Check module access permissions
my %access = &get_module_acl();
if (!$access{'full'}) {
    &error($text{'acl_denied'});
}

# Get and validate client IP address
my $client_ip = $ENV{'REMOTE_ADDR'} || '127.0.0.1';

if (!&is_valid_ip($client_ip)) {
    &log_action("Invalid IP address attempt: $client_ip");
    &error($text{'index_invalid_ip'});
}

# Normalize IPv6 address if needed
if ($client_ip =~ /:/) {
    my $packed = inet_pton(AF_INET6, $client_ip);
    if (!$packed) {
        &log_action("Failed to normalize IPv6: $client_ip");
        &error($text{'index_ipv6_error'});
    }
    $client_ip = inet_ntop(AF_INET6, $packed);
}

# Get UI path from ImunifyAV configuration
my $ui_path = &get_ui_path();
if (!$ui_path) {
    &log_action("UI path not configured");
    &error($text{'index_ui_path_error'});
}

my $htaccess_file = "$ui_path/.htaccess";

# Get and validate hostname
my $hostname = &get_system_hostname();
$hostname = &sanitize_input($hostname, 'hostname');

if (!$hostname || $hostname !~ /^[a-zA-Z0-9.\-]+$/) {
    &log_action("Invalid hostname: $hostname");
    &error($text{'index_invalid_hostname'});
}

# Get module version
my $module_version = $module_info{'version'} || '2.0.0';

# Update .htaccess to allow only current session IP
if (!&update_htaccess($htaccess_file, $client_ip)) {
    &log_action("Failed to update htaccess for IP: $client_ip");
    &error($text{'index_htaccess_error'});
}
&log_action("Updated htaccess for IP: $client_ip");

# Check if CSP is enabled
my $csp_enabled = &check_csp_enabled();

# Handle action parameter
my $action = $in{'action'} || '';
$action = &sanitize_input($action, 'alphanum');

# Validate action
if ($action && $action !~ /^(enable_csp)$/) {
    &log_action("Invalid action parameter: $action");
    &error($text{'error_invalid_action'});
}

# Process enable_csp action
if ($action eq 'enable_csp') {
    if (!$csp_enabled) {
        if (&enable_csp($hostname)) {
            &log_action("CSP enabled for hostname: $hostname");
            &webmin_log("enable", "csp", $hostname);
            $csp_enabled = 1;
        } else {
            &log_action("Failed to enable CSP");
        }
    }
    
    # Show success message and redirect
    &ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
    
    my $css_path = "$gconfig{'webprefix'}/$module_name/style.css";
    print "<link rel='stylesheet' href='$css_path'>\n";
    
    print "<div class='imunify360-message success'>\n";
    print "<p><strong>" . &html_escape($text{'index_csp_success'}) . "</strong></p>\n";
    print "<p>" . &html_escape($text{'index_csp_reload'}) . " ";
    print "<a href='index.cgi'>" . &html_escape($text{'index_click_here'}) . "</a></p>\n";
    print "</div>\n";
    
    print "<meta http-equiv='refresh' content='3;url=index.cgi'>\n";
    
    &ui_print_footer("/", $text{'index'});
    exit;
}

# Get authentication token from ImunifyAV
my $token = &get_imunify_token();
if (!$token) {
    &log_action("Failed to retrieve authentication token");
    # Check if agent exists
    if (!-x "/usr/bin/imunify360-agent") {
        &error("ImunifyAV agent not found at /usr/bin/imunify360-agent. Please install ImunifyAV first.");
    }
    &error($text{'index_token_error'});
}

&log_action("Token loaded successfully: " . &mask_token($token));

# Print page header
my $page_title = "$text{'index_title'} (v$module_version)";
&ui_print_header(undef, $page_title, "", undef, 1, 1);

# Use absolute path for CSS - $gconfig{'webprefix'} handles reverse proxy scenarios
my $css_path = "$gconfig{'webprefix'}/$module_name/style.css";
print "<link rel='stylesheet' href='$css_path'>\n";

# Navigation tabs
print "<div class='imunify360-tabs'>\n";
print "<a href='index.cgi' class='imunify360-tab active'>" . &html_escape($text{'index_dashboard'}) . "</a>\n";
print "<a href='settings.cgi' class='imunify360-tab'>" . &html_escape($text{'settings_title'}) . "</a>\n";
print "</div>\n";

# Main content
if (!$csp_enabled) {
    # Show CSP warning and enable button
    &log_action("CSP not enabled - showing warning");
    
    print "<div class='imunify360-warning'>\n";
    print "<p>" . &html_escape($text{'index_csp_warning'}) . "</p>\n";
    print &ui_form_start("index.cgi", "post");
    print &ui_hidden("action", "enable_csp");
    print &ui_submit($text{'index_csp_enable'});
    print &ui_form_end();
    print "</div>\n";
} else {
    # Display ImunifyAV iframe with secure token
    my $safe_hostname = &html_escape($hostname);
    my $safe_token = uri_escape($token);
    
    print "<div class='imunify360-container'>\n";
    print "<iframe ";
    print "src='https://$safe_hostname/imunifyav/#/login?token=$safe_token' ";
    print "class='imunify360-iframe' ";
    print "sandbox='allow-scripts allow-same-origin allow-forms allow-popups' ";
    print "referrerpolicy='strict-origin-when-cross-origin'>";
    print "</iframe>\n";
    print "</div>\n";
}

# Module Footer
print "<div style='text-align:center; margin-top:30px; padding:20px; border-top:1px solid #e0e0e0; color:#6c757d; font-size:13px;'>\n";
print "&copy; 2025 <a href='https://www.iq-hosting.com' target='_blank' style='color:#38ab63; text-decoration:none; font-weight:600;'>IQ Hosting</a> | ";
print "Community Module for ImunifyAV\n";
print "</div>\n";

# Print page footer
&ui_print_footer("/", $text{'index'});
