=head1 install_check.pl

Checks if ImunifyAV is properly installed and configured.

=cut

do 'imunifyav-lib.pl';

sub is_installed {
    my ($mode) = @_;
    
    # Check if imunify360-agent command exists and is executable
    if (!-x $imunify_agent) {
        return 0;
    }
    
    # Check if integration.conf exists and is readable
    if (!-r $integration_conf) {
        return 0;
    }
    
    # Check if ui_path is configured
    my $ui_path = &get_ui_path();
    if (!$ui_path || !-d $ui_path) {
        return 0;
    }
    
    # All checks passed
    return $mode + 1;
}

1;
