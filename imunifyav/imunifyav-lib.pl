=head1 imunifyav-lib.pl

Functions for managing ImunifyAV integration with Webmin.
This library provides secure token management, configuration handling,
and utility functions for the ImunifyAV Webmin module.

  foreign_require("imunifyav");
  my $token = imunifyav::get_imunify_token();
  my $ui_path = imunifyav::get_ui_path();

=cut

BEGIN { push(@INC, ".."); };
use WebminCore;

init_config();

our $module_config_directory = "$config_directory/imunifyav";
our $integration_conf = "/etc/sysconfig/imunify360/integration.conf";
our $notifications_conf = "$module_root_directory/notifications.conf";
our $log_file = "/var/log/imunifyav_webmin.log";
our $imunify_agent = "/usr/bin/imunify360-agent";

=head2 get_ui_path()

Returns the UI path from ImunifyAV integration.conf file.
Returns undef if the file doesn't exist or ui_path is not configured.

=cut
sub get_ui_path {
    my $ui_path = "";
    
    return undef unless -r $integration_conf;
    
    my $lref = &read_file_lines($integration_conf, 1);
    foreach my $line (@$lref) {
        if ($line =~ /^\s*ui_path\s*=\s*(.+)$/) {
            $ui_path = $1;
            $ui_path =~ s/^\s+|\s+$//g;
            # Security: Remove any path traversal attempts
            $ui_path =~ s/\.\.//g;
            $ui_path =~ s/\/+/\//g;
            last;
        }
    }
    
    return $ui_path && $ui_path ne '' ? $ui_path : undef;
}

=head2 get_imunify_token()

Gets authentication token from ImunifyAV agent securely.
Uses direct exec without shell to prevent command injection.
Returns the token string or undef on failure.

=cut
sub get_imunify_token {
    return undef unless -x $imunify_agent;
    
    my @cmd = ($imunify_agent, "login", "get", "--username", "root");
    
    my $pid = open(my $cmd_fh, '-|');
    
    if (!defined $pid) {
        &log_action("Fork failed for token retrieval: $!");
        return undef;
    }
    
    my $token;
    if ($pid == 0) {
        # Child process - execute command directly (no shell)
        exec(@cmd) or exit(1);
    } else {
        # Parent process - read output
        $token = <$cmd_fh>;
        close($cmd_fh);
    }
    
    return undef unless defined $token;
    chomp $token;
    $token =~ s/^\s+|\s+$//g;  # Trim whitespace
    
    # Log for debugging (masked)
    &log_action("Token received, length: " . length($token));
    
    # Validate token - allow alphanumeric, dots, underscores, hyphens, colons
    # ImunifyAV tokens can have various formats
    if (!$token || $token eq '' || length($token) < 10) {
        &log_action("Token too short or empty");
        return undef;
    }
    
    # Basic security check - no shell special characters
    if ($token =~ /[;&|`\$\(\)\{\}\[\]<>\\\/\s\n\r]/) {
        &log_action("Token contains invalid characters");
        return undef;
    }
    
    return $token;
}

=head2 log_action($message)

Logs an action to the module log file with timestamp.
Sanitizes the message to prevent log injection.

=cut
sub log_action {
    my ($message) = @_;
    
    # Sanitize message - remove newlines and control characters
    $message =~ s/[\r\n\x00-\x1f]//g;
    # Limit message length
    $message = substr($message, 0, 500) if length($message) > 500;
    
    my $time = localtime();
    my $user = $remote_user || 'unknown';
    
    # Use Webmin's safe file writing
    if (open(my $log_fh, '>>', $log_file)) {
        print $log_fh "[$time] [$user] $message\n";
        close($log_fh);
        chmod(0600, $log_file);
    }
}

=head2 mask_token($token)

Masks a token for safe logging, showing only last 10 characters.

=cut
sub mask_token {
    my ($token) = @_;
    return "****" . substr($token, -10) if length($token) > 10;
    return "****";
}

=head2 is_valid_ip($ip)

Validates IPv4 or IPv6 address format.
Returns 1 if valid, 0 otherwise.

=cut
sub is_valid_ip {
    my ($ip) = @_;
    
    return 0 unless defined $ip && $ip ne '';
    
    # IPv4 validation
    if ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
        return 0 if $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255;
        return 1;
    }
    
    # IPv6 validation (basic)
    if ($ip =~ /^[0-9a-fA-F:]+$/) {
        my $colons = () = $ip =~ /:/g;
        if ($ip =~ /::/) {
            return $colons <= 7 ? 1 : 0;
        } else {
            return $colons == 7 ? 1 : 0;
        }
    }
    
    return 0;
}

=head2 sanitize_input($input, $type)

Sanitizes user input based on type.
Types: 'alphanum', 'email', 'token', 'path', 'hostname'

=cut
sub sanitize_input {
    my ($input, $type) = @_;
    
    return '' unless defined $input;
    
    $type ||= 'alphanum';
    
    if ($type eq 'alphanum') {
        $input =~ s/[^a-zA-Z0-9_\-]//g;
    } elsif ($type eq 'email') {
        $input =~ s/[^a-zA-Z0-9\@\.\-_+]//g;
    } elsif ($type eq 'token') {
        $input =~ s/[^a-zA-Z0-9:_\-]//g;
    } elsif ($type eq 'path') {
        $input =~ s/\.\.//g;
        $input =~ s/[^a-zA-Z0-9_\-\.\/]//g;
        $input =~ s/\/+/\//g;
    } elsif ($type eq 'hostname') {
        $input =~ s/[^a-zA-Z0-9\.\-]//g;
    } elsif ($type eq 'chatid') {
        $input =~ s/[^0-9\-]//g;
    }
    
    return $input;
}

=head2 read_notification_config()

Reads notification settings from the config file.
Returns a hash with default values if file doesn't exist.

=cut
sub read_notification_config {
    my %config = (
        enable_telegram => 0,
        telegram_bot_token => '',
        telegram_chat_id => '',
        enable_email => 0,
        email_recipient => ''
    );
    
    if (-r $notifications_conf) {
        &read_file($notifications_conf, \%config);
    }
    
    return %config;
}

=head2 save_notification_config(\%config)

Saves notification settings to the config file securely.
Uses file locking to prevent race conditions.
Sets permissions to 644 so ImunifyAV hooks can read it.

=cut
sub save_notification_config {
    my ($config_ref) = @_;
    
    &lock_file($notifications_conf);
    &write_file($notifications_conf, $config_ref);
    # Use 644 instead of 600 so ImunifyAV can read the config
    # ImunifyAV runs hooks with different user context
    chmod(0644, $notifications_conf);
    &unlock_file($notifications_conf);
}

=head2 update_htaccess($htaccess_file, $client_ip)

Updates .htaccess file to allow only the specified IP.
Uses atomic write with temp file and proper locking.

=cut
sub update_htaccess {
    my ($htaccess_file, $client_ip) = @_;
    
    # Validate IP before writing
    return 0 unless &is_valid_ip($client_ip);
    
    my $temp_file = "$htaccess_file.tmp.$$";
    
    &lock_file($htaccess_file);
    
    eval {
        open(my $out, '>', $temp_file) or die "Cannot write to $temp_file: $!";
        print $out "# ImunifyAV Webmin Module - Auto-generated\n";
        print $out "# Only root session IP is allowed\n";
        print $out "Order deny,allow\n";
        print $out "Deny from all\n";
        print $out "Allow from $client_ip\n";
        close($out) or die "Cannot close $temp_file: $!";
        
        # Atomic replace
        rename($temp_file, $htaccess_file) or die "Cannot replace $htaccess_file: $!";
        chmod(0644, $htaccess_file);
    };
    
    if ($@) {
        &unlock_file($htaccess_file);
        unlink($temp_file) if -e $temp_file;
        &log_action("Failed to update htaccess: $@");
        return 0;
    }
    
    &unlock_file($htaccess_file);
    return 1;
}

=head2 check_csp_enabled()

Checks if Content-Security-Policy is enabled in Webmin config.
Returns 1 if enabled, 0 otherwise.

=cut
sub check_csp_enabled {
    my $webmin_config = "/etc/webmin/config";
    
    return 0 unless -r $webmin_config;
    
    my $lref = &read_file_lines($webmin_config, 1);
    foreach my $line (@$lref) {
        if ($line =~ /Content-Security-Policy.*frame-src/) {
            return 1;
        }
    }
    
    return 0;
}

=head2 enable_csp($hostname)

Enables Content-Security-Policy header in Webmin config.
Returns 1 on success, 0 on failure.

=cut
sub enable_csp {
    my ($hostname) = @_;
    
    # Validate hostname
    return 0 unless $hostname =~ /^[a-zA-Z0-9\.\-]+$/;
    
    my $webmin_config = "/etc/webmin/config";
    
    &lock_file($webmin_config);
    
    my $lref = &read_file_lines($webmin_config);
    
    # Check if already exists
    foreach my $line (@$lref) {
        if ($line =~ /Content-Security-Policy.*frame-src/) {
            &unlock_file($webmin_config);
            return 1; # Already enabled
        }
    }
    
    # Add CSP header
    my $csp_line = "extra_headers=Content-Security-Policy: frame-src 'self' https://$hostname/imunifyav/;";
    push(@$lref, $csp_line);
    
    &flush_file_lines($webmin_config);
    &unlock_file($webmin_config);
    
    return 1;
}

=head2 validate_email($email)

Validates email address format.
Returns 1 if valid, 0 otherwise.

=cut
sub validate_email {
    my ($email) = @_;
    return 0 unless defined $email && $email ne '';
    return $email =~ /^[^\s\@]+\@[^\s\@]+\.[^\s\@]+$/ ? 1 : 0;
}

=head2 get_hooks_file()

Returns the path to ImunifyAV hooks configuration file.

=cut
sub get_hooks_file {
    return "/etc/sysconfig/imunify360/hooks.yaml";
}

=head2 check_hooks_installed()

Checks if our notification hooks are installed in ImunifyAV.
Returns 1 if installed, 0 otherwise.

=cut
sub check_hooks_installed {
    my $hooks_file = &get_hooks_file();
    my $script_path = "$module_root_directory/imunifyscan.pl";
    
    return 0 unless -r $hooks_file;
    
    my $content = &read_file_contents($hooks_file);
    return 0 unless $content;
    
    # Check if our script is referenced
    return $content =~ /\Q$script_path\E/ ? 1 : 0;
}

=head2 install_hooks()

Installs notification hooks into ImunifyAV hooks.yaml file.
Returns 1 on success, 0 on failure.

=cut
sub install_hooks {
    my $hooks_file = &get_hooks_file();
    my $script_path = "$module_root_directory/imunifyscan.pl";
    
    # Check if hooks file directory exists
    my $hooks_dir = "/etc/sysconfig/imunify360";
    return 0 unless -d $hooks_dir;
    
    # Create hooks configuration matching ImunifyAV format exactly
    my $hooks_content = "rules:\n";
    
    # CUSTOM_SCAN_FINISHED - disabled
    $hooks_content .= "  CUSTOM_SCAN_FINISHED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # CUSTOM_SCAN_MALWARE_FOUND - enabled
    $hooks_content .= "  CUSTOM_SCAN_MALWARE_FOUND:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: true\n";
    $hooks_content .= "      scripts:\n";
    $hooks_content .= "      - $script_path\n";
    
    # CUSTOM_SCAN_STARTED - enabled
    $hooks_content .= "  CUSTOM_SCAN_STARTED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: true\n";
    $hooks_content .= "      scripts:\n";
    $hooks_content .= "      - $script_path\n";
    
    # USER_SCAN_FINISHED - disabled
    $hooks_content .= "  USER_SCAN_FINISHED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # USER_SCAN_MALWARE_FOUND - enabled
    $hooks_content .= "  USER_SCAN_MALWARE_FOUND:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: true\n";
    $hooks_content .= "      scripts:\n";
    $hooks_content .= "      - $script_path\n";
    
    # USER_SCAN_STARTED - enabled
    $hooks_content .= "  USER_SCAN_STARTED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: true\n";
    $hooks_content .= "      scripts:\n";
    $hooks_content .= "      - $script_path\n";
    
    # Backup existing file if it exists
    if (-e $hooks_file) {
        my $backup = "$hooks_file.backup." . time();
        system("cp", "-p", $hooks_file, $backup);
    }
    
    # Write new hooks file
    &lock_file($hooks_file);
    
    if (open(my $fh, '>', $hooks_file)) {
        print $fh $hooks_content;
        close($fh);
        # Set correct permissions: 640
        chmod(0640, $hooks_file);
        # Try to set group to match ImunifyAV
        # Check common group names
        my $imunify_group = '';
        if (getgrnam('_imunify')) {
            $imunify_group = '_imunify';
        } elsif (getgrnam('imunify')) {
            $imunify_group = 'imunify';
        } elsif (getgrnam('imunify360')) {
            $imunify_group = 'imunify360';
        }
        
        if ($imunify_group) {
            system("chgrp", $imunify_group, $hooks_file);
        }
        # If no imunify group found, keep root group (still works)
        
        &unlock_file($hooks_file);
        return 1;
    }
    
    &unlock_file($hooks_file);
    return 0;
}

=head2 remove_hooks()

Disables notification hooks in ImunifyAV hooks.yaml file.
Sets enabled to false instead of removing the configuration.
Returns 1 on success, 0 on failure.

=cut
sub remove_hooks {
    my $hooks_file = &get_hooks_file();
    my $script_path = "$module_root_directory/imunifyscan.pl";
    
    return 1 unless -e $hooks_file;
    
    # Create hooks configuration with all disabled
    my $hooks_content = "rules:\n";
    
    # CUSTOM_SCAN_FINISHED - disabled
    $hooks_content .= "  CUSTOM_SCAN_FINISHED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # CUSTOM_SCAN_MALWARE_FOUND - disabled
    $hooks_content .= "  CUSTOM_SCAN_MALWARE_FOUND:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # CUSTOM_SCAN_STARTED - disabled
    $hooks_content .= "  CUSTOM_SCAN_STARTED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # USER_SCAN_FINISHED - disabled
    $hooks_content .= "  USER_SCAN_FINISHED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # USER_SCAN_MALWARE_FOUND - disabled
    $hooks_content .= "  USER_SCAN_MALWARE_FOUND:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # USER_SCAN_STARTED - disabled
    $hooks_content .= "  USER_SCAN_STARTED:\n";
    $hooks_content .= "    SCRIPT:\n";
    $hooks_content .= "      enabled: false\n";
    $hooks_content .= "      scripts: []\n";
    
    # Write disabled hooks file
    &lock_file($hooks_file);
    
    if (open(my $fh, '>', $hooks_file)) {
        print $fh $hooks_content;
        close($fh);
        # Set correct permissions: 640
        chmod(0640, $hooks_file);
        # Try to set group to match ImunifyAV
        my $imunify_group = '';
        if (getgrnam('_imunify')) {
            $imunify_group = '_imunify';
        } elsif (getgrnam('imunify')) {
            $imunify_group = 'imunify';
        } elsif (getgrnam('imunify360')) {
            $imunify_group = 'imunify360';
        }
        
        if ($imunify_group) {
            system("chgrp", $imunify_group, $hooks_file);
        }
        
        &unlock_file($hooks_file);
        return 1;
    }
    
    &unlock_file($hooks_file);
    return 0;
}

1;
