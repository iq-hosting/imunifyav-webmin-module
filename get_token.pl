#!/usr/bin/perl
use strict;
use warnings;

sub get_token {
    my $token_file = "imunifytokens.txt";  # Replace with actual path
    system("imunify360-agent login get --username root > $token_file");
    open(my $fh, '<', $token_file) or die "Could not open token file: $!";
    my $token = <$fh>;
    close($fh);
    unlink $token_file;  # Clean up the token file
    chomp $token;
    return $token;
}

1;  # Return a true value
