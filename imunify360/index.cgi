#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use WebminCore;
use Socket qw(AF_INET AF_INET6 inet_pton inet_ntop);
use Sys::Hostname;
use Time::HiRes qw(time);
use HTML::Entities;

&init_config();
my $cgi = CGI->new();
my $hostname = encode_entities(hostname());
my $htaccess_file = "/home/._default_hostname/public_html/.htaccess";
my $config_conf = "/etc/webmin/config";
my $log_file = "/var/log/imunify360_changes.log";
my $info_file = '/usr/libexec/webmin/imunify360/module.info';
my $csp_enabled = 0;
my $module_version = 'Unknown';
my $token = "";

if (-e $info_file) {
    open(my $info_fh, '<', $info_file) or die "Could not open info file: $!";
    while (my $line = <$info_fh>) {
        chomp $line;
        if ($line =~ /^version\s*=\s*(.+)$/) {
            $module_version = $1;
            last;
        }
    }
    close($info_fh);
}

if ($hostname !~ /^[a-zA-Z0-9.-]+$/) {
    die "Invalid hostname.";
}

sub sanitize_path {
    my $path = shift;
    $path =~ s/\.\.//g;
    $path =~ s/\/+/\//g;
    return $path;
}

$config_conf = sanitize_path($config_conf);


sub log_change {
    my $message = shift;
    $message =~ s/[\r\n]//g;
    $message = encode_entities($message);
    open(my $log, '>>', $log_file) or die "Could not open log file: $!";
    print $log "[" . localtime() . "] $message\n";
    close($log);
}


sub is_valid_ipv4 {
    my $ip = shift;
    return $ip =~ /^(\d{1,3}\.){3}\d{1,3}$/ && !grep { $_ > 255 } split(/\./, $ip);
}


sub is_valid_ipv6 {
    my $ip = shift;

    return 0 unless $ip =~ /^[0-9a-fA-F:]+$/;

    my $colon_count = () = $ip =~ /:/g;

    if ($ip =~ /::/) {
        return $colon_count <= 7;
    } else {
        return $colon_count == 7;
    }
}

sub is_valid_ip {
    my $ip = shift;
    return is_valid_ipv4($ip) || is_valid_ipv6($ip);
}


my $client_ip = encode_entities($ENV{'REMOTE_ADDR'} // '127.0.0.1');
if (!is_valid_ip($client_ip)) {
    log_change("Invalid IP address attempt: $client_ip");
    die "Invalid IP address.";
}

if ($client_ip =~ /:/) {
    my $packed = inet_pton(AF_INET6, $client_ip);
    unless ($packed) {
        log_change("Failed to normalize IPv6 address: $client_ip");
        die "Failed to normalize IPv6 address: $client_ip.";
    }
    $client_ip = inet_ntop(AF_INET6, $packed);
}

sub allow_root_ip {
    my $temp_htaccess = "$htaccess_file.tmp";

    open(my $out, '>', $temp_htaccess) or die "Could not write to $temp_htaccess: $!";

    print $out "Deny from all\n";

    print $out "Allow from $client_ip\n";

    close($out) or die "Could not close $temp_htaccess: $!";

    rename $temp_htaccess, $htaccess_file or die "Could not replace $htaccess_file: $!";

    chmod 0644, $htaccess_file or log_change("Failed to set secure permissions for $htaccess_file.");
}

allow_root_ip();
log_change("Updated .htaccess to deny all and allow " . encode_entities($client_ip));


sub mask_token_last {
    my $token = shift;
    return "****" . substr($token, -25);
}

eval {
    require '/usr/libexec/webmin/imunify360/get_token.pl';
    $token = get_token();
    log_change("Token successfully loaded: " . mask_token_last($token));
};
if ($@) {
    log_change("Error loading token: $@");
    die "Error loading token: $@";
}

print $cgi->header();



my $header_title = "Imunify360 Manager (v$module_version)";
print $cgi->header();
print &header($header_title, "", "");
print "<style>

    .imunify360-warning {
        border: 1px solid #f39c12;
        border-radius: 10px;
        padding: 20px;
        background-color: #fdf6e3;
        color: #d35400;
        width: 90%;
        max-width: 600px;
        text-align: center;
        box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.1);
        margin: 20px auto;
        font-weight: bold;
    }
    .imunify360-warning button {
        background-color: #f39c12;
        border: none;
        color: #fff;
        font-size: 14px;
        padding: 10px 20px;
        border-radius: 5px;
        cursor: pointer;
        transition: all 0.3s ease;
    }
    .imunify360-warning button:hover {
        background-color: #e67e22;
    }
    body.imunify360 {
        font-family: 'Arial', sans-serif;
        background-color: #f4f6f9;
        margin: 0;
        padding: 20px;
        line-height: 1.6;
        color: #333;
        height: 100%;
    }
    h1.imunify360-header {
        color: #4a90e2;
        text-align: center;
        font-size: 28px;
        margin-bottom: 20px;
    }
    .imunify360-container {
    height: 100%;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    margin: 0;
}
    .imunify360-iframe {
    display: block;
    border: none;
    height: 100vh;
    width: 100%;
    }
    .imunify360-message {
        border: 1px solid #ddd;
        border-radius: 10px;
        padding: 20px;
        background-color: #fff;
        width: 90%;
        max-width: 600px;
        text-align: center;
        box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.1);
    }
    .imunify360-message.success {
        color: #2ecc71;
        border-color: #2ecc71;
    }
    .imunify360-message.error {
        color: #e74c3c;
        border-color: #e74c3c;
    }
    .imunify360-small-btn {
        padding: 8px 15px;
        font-size: 14px;
        font-weight: bold;
        color: #fff;
        border: none;
        border-radius: 5px;
        cursor: pointer;
        background: linear-gradient(135deg, #4a90e2, #0056b3);
        transition: all 0.3s ease;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }
    .imunify360-small-btn:hover {
        background: linear-gradient(135deg, #0056b3, #003d82);
        transform: scale(1.05);
    }
</style>";


print "<body class='imunify360'>";
print "<div class='imunify360-container'>";

# Check if CSP already exists
open(my $fh, '<', $config_conf) or die "Could not open $config_conf: $!";
while (<$fh>) {
    if (/Content-Security-Policy/) {
    log_change("CSP already present in configuration.");
    $csp_enabled = 1;
        last;
    }
}
close($fh);


my $action = $cgi->param('action') // '';
$action = encode_entities($action);
if ($action && $action !~ /^(enable_csp|)$/) {
    log_change("Invalid action parameter: $action");
    print "<div class='imunify360-message error'>Invalid action parameter: $action</div>";
    exit;
}


if ($action eq 'enable_csp') {
    unless ($csp_enabled) {
        eval {
            open(my $fh, '>>', $config_conf) or die "Could not open $config_conf: $!";
            print $fh "extra_headers=Content-Security-Policy: frame-src 'self' https://$hostname/imunifyav/;\n";
            close($fh);
        };
        if ($@) {
            log_change("Failed to enable CSP in $config_conf: $@");
            print "<div class='imunify360-message error'>
            <p>Failed to enable Content-Security-Policy (CSP). Please check permissions or try again.</p>
            </div>";
            exit;
        }

        log_change("CSP successfully enabled in $config_conf. Hostname: $hostname, IP: $client_ip");
        $csp_enabled = 1;
    }

    print "<div class='imunify360-message success'>
        <p><strong>Content-Security-Policy (CSP) enabled successfully.</strong></p>
        <p>Reloading the page to apply changes... <a href='/imunify360/?xnavigation=1'>Click here</a> if the page does not reload automatically.</p>
 </div>";
    print "<meta http-equiv='refresh' content='3;url=index.cgi?xnavigation=1'>";
    exit;
}

if (!$csp_enabled && $action eq '') {
    log_change("Warning: CSP is not enabled. Configuration file: $config_conf. Please add it: extra_headers=Content-Security-Policy: frame-src 'self' https://$hostname/imunifyav/;");
     print "<div class='imunify360-warning'>
        <p>Warning: To enhance security, please enable the Content-Security-Policy (CSP) header.</p>
        <form method='get' action='index.cgi'>
            <input type='hidden' name='action' value='enable_csp'>
            <button type='submit'>Enable CSP</button>
        </form>
    </div>";
} else {

    print "<iframe src='https://$hostname/imunifyav/#/login?token=$token' class='imunify360-iframe'></iframe>";

}

print "</div>";
print "</body>";
print &footer();
