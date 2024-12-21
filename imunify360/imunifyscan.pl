#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use LWP::UserAgent;

# Notification Settings
my $enable_telegram = 1; # Set to 0 to disable Telegram notifications
my $enable_email    = 1; # Set to 0 to disable Email notifications

# Telegram Bot Settings
my $telegram_bot_token = "bot_token";
my $telegram_chat_id   = "chat_id";

# Email Notification Settings
my $email_recipient = 'youremail@example.com';

# Read the payload from stdin
my $payload;
{
    local $/; 
    $payload = <STDIN>;
}

open(my $dump_fh, '>', "/tmp/imunify-script-dump.json") or warn "Could not save debug payload: $!";
print $dump_fh $payload;
close($dump_fh);

# Parse JSON payload
my $data = decode_json($payload);

# Extract event details
my $event_id = $data->{event_id} // "UNKNOWN";

# Extract user information
my $user = $data->{initiator} // "undefined";
if ($user eq "undefined" || $user eq "") {
    $user = $data->{path} // "";
    if ($user =~ m{([^/]+)$}) {
        $user = $1;
    } else {
        $user = "UNKNOWN";
    }
}

my $hostname = `hostname -f`;
chomp($hostname);

# Notification Functions
sub send_telegram {
    my ($message) = @_;
    return unless $enable_telegram;

    my $ua = LWP::UserAgent->new;
    my $url = "https://api.telegram.org/bot$telegram_bot_token/sendMessage";
    my $response = $ua->post(
        $url,
        [
            chat_id => $telegram_chat_id,
            text    => $message,
        ]
    );

    if (!$response->is_success) {
        warn "Failed to send Telegram message: " . $response->status_line;
    }
}

sub send_email {
    my ($subject, $body) = @_;
    return unless $enable_email;

    open(my $mail, "|-", "/usr/sbin/sendmail -t") or warn "Could not open sendmail: $!";
    print $mail "To: $email_recipient\n";
    print $mail "Subject: $subject\n\n";
    print $mail "$body\n";
    close($mail);
}

# Event Handlers
sub handle_malware_found {
    my $malicious_total = $data->{total_malicious} // 0;
    my $malicious_files = join(", ", @{$data->{malicious_files}}) // "None";

    my $message = "⚠️ Malware detected by $user on $hostname. Total: $malicious_total. Files: $malicious_files";

    send_telegram($message);
    send_email("Malware Alert on $hostname", $message);
}

sub handle_scan_started {
    my $path = $data->{path} // "Unknown";

    my $message = "✅ Scan started by $user on $hostname. Path: $path";

    send_telegram($message);
    send_email("Scan Started on $hostname", $message);
}

# Dispatch events
if ($event_id eq 'USER_SCAN_MALWARE_FOUND' || $event_id eq 'CUSTOM_SCAN_MALWARE_DETECTED') {
    handle_malware_found();
} elsif ($event_id eq 'USER_SCAN_STARTED' || $event_id eq 'CUSTOM_SCAN_STARTED') {
    handle_scan_started();
} else {
    warn "Unhandled event ID: $event_id";
}
