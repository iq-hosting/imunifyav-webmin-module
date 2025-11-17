#!/usr/bin/perl
#
# ImunifyAV Scan Event Handler
# Processes scan events and sends notifications via Telegram/Email
# This script is called by ImunifyAV event hooks
#

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use Sys::Hostname;

# Configuration file path
my $config_file = '/usr/libexec/webmin/imunifyav/notifications.conf';
my $log_file = '/var/log/imunifyav_scan_events.log';

# Log events
sub log_event {
    my ($message) = @_;
    $message =~ s/[\r\n]//g;
    
    if (open(my $log, '>>', $log_file)) {
        my $time = localtime();
        print $log "[$time] $message\n";
        close($log);
    }
}

# Read notification configuration
sub read_notification_config {
    my %config = (
        enable_telegram => 0,
        telegram_bot_token => '',
        telegram_chat_id => '',
        enable_email => 0,
        email_recipient => ''
    );

    return %config unless -e $config_file && -r $config_file;

    open(my $fh, '<', $config_file) or return %config;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
        if ($line =~ /^(\w+)\s*=\s*(.*)$/) {
            my ($key, $value) = ($1, $2);
            $value =~ s/^\s+|\s+$//g;
            $config{$key} = $value if exists $config{$key};
        }
    }
    close($fh);

    return %config;
}

# Sanitize string for safe output
sub sanitize_string {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/[<>&'"\\]//g;
    $str = substr($str, 0, 500) if length($str) > 500;
    return $str;
}

# Load configuration
my %notification_config = read_notification_config();

my $enable_telegram = $notification_config{enable_telegram};
my $enable_email = $notification_config{enable_email};
my $telegram_bot_token = $notification_config{telegram_bot_token};
my $telegram_chat_id = $notification_config{telegram_chat_id};
my $email_recipient = $notification_config{email_recipient};

# Read the payload from stdin
my $payload = '';
{
    local $/;
    $payload = <STDIN>;
}

# Exit if no payload
unless ($payload) {
    log_event("No payload received");
    exit 0;
}

# Save debug dump
my $dump_file = "/tmp/imunify-event-$$.json";
if (open(my $dump_fh, '>', $dump_file)) {
    print $dump_fh $payload;
    close($dump_fh);
}

# Parse JSON payload
my $data;
eval {
    $data = decode_json($payload);
};
if ($@) {
    log_event("Failed to parse JSON: $@");
    exit 1;
}

# Extract event details
my $event_id = $data->{event_id} // "UNKNOWN";
$event_id = sanitize_string($event_id);

# Extract user information safely
my $user = $data->{initiator} // "";
if (!$user || $user eq "" || $user eq "undefined") {
    $user = $data->{path} // "";
    if ($user =~ m{/home/([^/]+)/}) {
        $user = $1;
    } elsif ($user =~ m{/home/([^/]+)$}) {
        $user = $1;
    } elsif ($user =~ m{([^/]+)$}) {
        $user = $1;
    } else {
        $user = "system";
    }
}
$user = sanitize_string($user);

# Get hostname safely
my $hostname = eval { hostname() } // 'unknown';
$hostname =~ s/[^a-zA-Z0-9.\-]//g;

log_event("Processing event: $event_id for user: $user");

# Send Telegram notification
sub send_telegram {
    my ($message) = @_;
    return unless $enable_telegram && $telegram_bot_token && $telegram_chat_id;

    my $ua = LWP::UserAgent->new(timeout => 30);
    my $url = "https://api.telegram.org/bot$telegram_bot_token/sendMessage";
    
    my $response = $ua->post(
        $url,
        [
            chat_id => $telegram_chat_id,
            text    => $message,
        ]
    );

    if ($response->is_success) {
        log_event("Telegram notification sent successfully");
    } else {
        log_event("Failed to send Telegram: " . $response->status_line);
    }
}

# Send Email notification
sub send_email {
    my ($subject, $body) = @_;
    return unless $enable_email && $email_recipient;

    $subject =~ s/[\r\n]//g;

    my $sendmail = '/usr/sbin/sendmail';
    return unless -x $sendmail;

    my $pid = open(my $mail, '|-');
    return unless defined $pid;
    
    if ($pid == 0) {
        exec($sendmail, '-t') or exit(1);
    }
    
    print $mail "To: $email_recipient\n";
    print $mail "Subject: $subject\n";
    print $mail "Content-Type: text/plain; charset=UTF-8\n";
    print $mail "\n";
    print $mail "$body\n";
    close($mail);
    
    log_event("Email notification sent to: $email_recipient");
}

# Handle malware detection event
sub handle_malware_found {
    my $malicious_total = $data->{total_malicious} // 0;
    $malicious_total = int($malicious_total);
    
    my $malicious_files = "None";
    if (ref($data->{malicious_files}) eq 'ARRAY' && @{$data->{malicious_files}}) {
        my @files = @{$data->{malicious_files}};
        @files = @files[0..9] if @files > 10;
        @files = map { sanitize_string($_) } @files;
        $malicious_files = join("\n- ", @files);
    }

    my $telegram_msg = "⚠️ Malware Detected\n\n";
    $telegram_msg .= "Server: $hostname\n";
    $telegram_msg .= "User: $user\n";
    $telegram_msg .= "Total Malicious: $malicious_total\n";
    
    my $email_subject = "[$hostname] Malware Alert - $malicious_total files detected";
    my $email_body = "Malware Detection Alert\n";
    $email_body .= "========================\n\n";
    $email_body .= "Server: $hostname\n";
    $email_body .= "User/Initiator: $user\n";
    $email_body .= "Total Malicious Files: $malicious_total\n\n";
    $email_body .= "Files:\n- $malicious_files\n";

    send_telegram($telegram_msg);
    send_email($email_subject, $email_body);
    
    log_event("Malware alert sent: $malicious_total files for $user");
}

# Handle scan started event
sub handle_scan_started {
    my $path = $data->{path} // "Unknown";
    $path = sanitize_string($path);

    my $telegram_msg = "✅ Scan Started\n\n";
    $telegram_msg .= "Server: $hostname\n";
    $telegram_msg .= "User: $user\n";
    $telegram_msg .= "Path: $path\n";

    my $email_subject = "[$hostname] Scan Started by $user";
    my $email_body = "Scan Started Notification\n";
    $email_body .= "=========================\n\n";
    $email_body .= "Server: $hostname\n";
    $email_body .= "User/Initiator: $user\n";
    $email_body .= "Path: $path\n";

    send_telegram($telegram_msg);
    send_email($email_subject, $email_body);
    
    log_event("Scan started notification sent for $user on $path");
}

# Dispatch events based on event_id
if ($event_id eq 'USER_SCAN_MALWARE_FOUND' || $event_id eq 'CUSTOM_SCAN_MALWARE_FOUND') {
    handle_malware_found();
} elsif ($event_id eq 'USER_SCAN_STARTED' || $event_id eq 'CUSTOM_SCAN_STARTED') {
    handle_scan_started();
} else {
    log_event("Unhandled event ID: $event_id");
}

exit 0;
