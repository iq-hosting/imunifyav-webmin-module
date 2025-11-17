=head1 log_parser.pl

Converts ImunifyAV module action logs into human-readable format
for display in Webmin Actions Log module.

=cut

require 'imunifyav-lib.pl';

sub parse_webmin_log {
    my ($user, $script, $action, $type, $object, $params, $long) = @_;
    
    if ($action eq 'enable' && $type eq 'csp') {
        if ($long) {
            return &text('log_enable_csp') . " for hostname: $object";
        }
        return &text('log_enable_csp');
    }
    elsif ($action eq 'save' && $type eq 'notifications') {
        if ($long) {
            my $telegram = $params->{'enable_telegram'} ? 'enabled' : 'disabled';
            my $email = $params->{'enable_email'} ? 'enabled' : 'disabled';
            return &text('log_save_settings') . " (Telegram: $telegram, Email: $email)";
        }
        return &text('log_save_settings');
    }
    elsif ($action eq 'update' && $type eq 'htaccess') {
        if ($long) {
            return &text('log_update_htaccess') . " for IP: $object";
        }
        return &text('log_update_htaccess');
    }
    else {
        return undef;
    }
}

1;
