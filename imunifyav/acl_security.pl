=head1 acl_security.pl

Access control configuration for ImunifyAV module.
Since this module is for root only, we provide a simple full access control.

=cut

require 'imunifyav-lib.pl';

sub acl_security_form {
    my ($o) = @_;
    
    print &ui_table_row($text{'acl_full'},
        &ui_yesno_radio("full", $o->{'full'}));
}

sub acl_security_save {
    my ($o, $in) = @_;
    
    $o->{'full'} = $in->{'full'};
}

1;
