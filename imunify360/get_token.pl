#!/usr/bin/perl
use strict;
use warnings;

sub get_token {
    my $token_file = "imunifytokens";
    system("imunify360-agent login get --username root > $token_file");
    chmod 0600, $token_file;
    open(my $fh, '<', $token_file) or die "Could not open token file: $!";
    my $token = <$fh>;
    close($fh);
    chomp $token;

    if (open(my $empty_fh, '>', $token_file)) {
        print $empty_fh "";
        close($empty_fh);
    } else {
        log_change("Failed to empty token file $token_file.");
    }

    return $token;
}

1;
