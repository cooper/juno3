#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package channel::modes;

use warnings;
use strict;

use utils 'log2';

# constants
sub normal        () { 0 }
sub parameter     () { 1 }
sub parameter_set () { 2 }

my %blocks;

# local modes
# eventually this will all be in utils.pm # TODO
# types:
#   normal (0)
#   parameter (1)
#   parameter_set (2)
# I was gonna make a separate type for status modes but
my %modes = (
    no_ext        => [normal, 'n'],
    protect_topic => [normal, 't'],
    moderated     => [normal, 'm']
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

# register a block check to a mode
sub register_block {
    my ($name, $what, $code) = @_;
    if (ref $code ne 'CODE') {
        log2((caller)[0]." tried to register a block to $name that isn't CODE.");
        return
    }
    if (exists $blocks{$name}{$what}) {
        log2((caller)[0]." tried to register $what to $name which is already registered");
        return
    }
    log2("registered $what to $name");
    $blocks{$name}{$what} = $code;
    return 1
}

sub fire {
    my ($channel, $server, $state, $name, $parameter) = @_;
    
}

1
