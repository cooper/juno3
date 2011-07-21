#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::modes;

use warnings;
use strict;

use utils 'log2';

my %blocks;

# local modes
# eventually this will all be in utils.pm # TODO
my %modes = (
    ircop     => 'o',
    invisible => 'i'
);

# here we create the internal mode "blocks"
# which are called by a mode handler.
# if any blocks of a mode return false,
# the mode will not be set.
# they have unique names because some API
# modules might want to override or remove them.
log2("registering internal mode blocks");

# block for oper
register_block('ircop', 'internal_ircop', sub {
    my ($user, $state) = @_;
    if ($state) {
        # never allow users to set ircop
        return
    }
    # but always allow them to unset it
    log2("removing all flags from $$user{nick}");
    $user->{flags} = [];
    return 1
});

log2("end internal mode blocks");

# local modes
# this just tells the internal server what
# mode is associated with what letter
sub add_internal_modes {
    my $server = shift;
    log2("registering internal modes");
    foreach my $name (keys %modes) {
        $server->add_umode($name, $modes{$name});
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

# call on mode change
sub fire {
    my ($user, $state, $name) = @_;
    if (!exists $blocks{$name}) {
        # nothing to do
        return 1
    }
    foreach my $block (values %{$blocks{$name}}) {
        return unless $block->($user, $state)
    }
    return 1
}

1
