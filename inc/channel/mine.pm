#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper

# this file contains channely stuff for local users
# and even some servery channely stuff.
package channel::mine;

use warnings;
use strict;

use utils;

# omg hax
# it has the same name as the one in channel.pm.
# the only difference is that this one sends
# the mode changes around
sub join {
    my ($channel, $user, $time) = @_;
    return if $channel->has_user($user);
    $channel->join($user, $time);

    # for each user in the channel
    foreach my $usr (@{$channel->{users}}) {
        next unless $usr->is_local;
        $usr->sendfrom($user->full, "JOIN $$channel{name}")
    }

    names($channel, $user);
    $user->numeric('RPL_ENDOFNAMES', $channel->{name});
    $user->numeric('RPL_CREATIONTIME', $channel->{name}, $channel->{time});

    return $channel->{time};
}

sub names {
    my ($channel, $user) = @_;
    my $str = '';
    foreach my $usr (@{$channel->{users}}) {
        $str .= $usr->{nick}.q( )
    }
    $user->numeric('RPL_NAMEREPLY', '=', $channel->{name}, $str) if $str ne '';
}

1
