#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper

# this file contains channely stuff for local users
# and even some servery channely stuff.
package channel::mine;

use warnings;
use strict;

use utils;

our %prefix = (
    owner  => '~',
    admin  => '&',
    op     => '@',
    halfop => '%',
    voice  => '+'
);

# omg hax
# it has the same name as the one in channel.pm.
# the only difference is that this one sends
# the mode changes around
sub cjoin {
    my ($channel, $user, $time) = @_;
    return if $channel->has_user($user);
    $channel->cjoin($user, $time);

    # for each user in the channel
    foreach my $usr (@{$channel->{users}}) {
        next unless $usr->is_local;
        $usr->sendfrom($user->full, "JOIN $$channel{name}")
    }

    names($channel, $user);
    $user->numeric('RPL_ENDOFNAMES', $channel->{name});

    return $channel->{time};
}

sub names {
    my ($channel, $user) = @_;
    my $str = '';
    foreach my $usr (@{$channel->{users}}) {
        # find their prefix
        my $prefix =
          $channel->list_has('owner',  $usr) ? $prefix{owner}  :
          $channel->list_has('admin',  $usr) ? $prefix{admin}  :
          $channel->list_has('op',     $usr) ? $prefix{op}     :
          $channel->list_has('halfop', $usr) ? $prefix{halfop} :
          $channel->list_has('voice',  $usr) ? $prefix{voice}  : q..;

        $str .= $prefix.$usr->{nick}.q( )
    }
    $user->numeric('RPL_NAMEREPLY', '=', $channel->{name}, $str) if $str ne '';
}

sub modes {
    my ($channel, $user) = @_;
    $user->numeric('RPL_CHANNELMODEIS', $channel->{name}, $channel->mode_string($user->{server}));
    $user->numeric('RPL_CREATIONTIME', $channel->{name}, $channel->{time});
}

sub send_all {
    my ($channel, $what, $ignore) = @_;
    foreach my $user (@{$channel->{users}}) {
        next unless $user->is_local;
        next if defined $ignore && $ignore == $user;
        $user->send($what);
    }
    return 1
}

# send to all members of channels in common
# with a user, but only once.
sub send_all_user {
    my ($user, $what) = @_;
    $user->sendfrom($user->full, $what);
    my %sent = ( $user => 1 );

    foreach my $channel (values %channel::channels) {
        next unless $channel->has_user($user);

        # send to each member
        foreach my $usr (@{$channel->{users}}) {
            next unless $usr->is_local;
            next if $sent{$usr};
            $usr->sendfrom($user->full, $what);
            $sent{$usr} = 1
        }

    }
}

1
