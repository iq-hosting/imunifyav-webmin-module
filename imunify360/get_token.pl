#!/usr/bin/perl
use strict;
use warnings;

sub get_token {
    my $token_file = "imunifytokens.txt";
    system("imunify360-agent login get --username root > $token_file");
    chmod 0600, $token_file or die "Could not set permissions on $token_file: $!";
    open(my $fh, '<', $token_file) or die "Could not open token file: $!";
    my $token = <$fh>;
    close($fh);
    chomp $token;
    sleep 1;
    if (unlink $token_file) {
        log_change("Token file $token_file deleted successfully.");
    } else {
        log_change("Failed to delete token file $token_file.");
    }
    return $token;
}
1;
