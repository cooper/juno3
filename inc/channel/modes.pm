#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package channel::modes;

use warnings;
use strict;

use utils 'log2';

my %blocks;

# local modes
# eventually this will all be in utils.pm # TODO
# types:
#   0: normal
#   1: parameter
# I was gonna make a separate type for status modes but
my %modes = (
    no_ext        => [0, 'n'],
    protect_topic => [0, 't'],
    moderated     => [0, 'm']
);

# this just tells the internal server what
# mode is associated with what letter and type
sub add_internal_modes {
    my $server = shift;
    log2("registering internal channel modes");
    foreach my $name (keys %modes) {
        $server->add_cmode($name, $modes{$name}[1], $modes{$name}[0]);
    }
    log2("end of internal modes");
}

sub fire {1}

1
