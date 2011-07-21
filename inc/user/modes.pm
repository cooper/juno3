#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::modes;

use warnings;
use strict;

use utils 'log2';

my %modes = (
    ircop => {
        letter => 'o',
        test => [\&ircop_test]
    },
    invisible => {
        letter => 'i'
    }
);

sub add_internal_modes {
    my $server = shift;

    $server->{umode_tests}  = {};
    $server->{chmode_tests} = {};

    log2("registering internal modes");
    foreach my $name (keys %modes) {
        $server->add_umode($name, $modes{$name}{letter}, @{$modes{$name}{test}});
    }
    log2("end of internal modes");
}

sub ircop_test {
    my ($user, $state) = @_;

    # always allow unset.
    return 1 unless $state;

    # but never allow anything else; that's a server's job
    return
}

1
