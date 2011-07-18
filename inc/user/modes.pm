#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::modes;

use warnings;
use strict;

use utils 'log2';

my %modes = (
    ircop     => 'o',
    invisible => 'i'
);

sub add_internal_modes {
    my $server = shift;
    log2("registering internal modes");
    while (my ($name, $letter) = each %modes) {
        $server->add_umode($name, $letter);
    }
    log2("end of internal modes");
}

1
