#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper

# this file contains channely stuff for local users
# and even some servery channely stuff.
package channel::mine;

use warnings;
use strict;

use utils qw[log2 conf gv];

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
    my @str;
    my $curr = 0;
    foreach my $usr (@{$channel->{users}}) {
        $str[$curr] .= prefix($channel, $usr).$usr->{nick}.q( );
        $curr++ if length $str[$curr] > 500
    }
    $user->numeric('RPL_NAMEREPLY', '=', $channel->{name}, $_) foreach @str
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

# send a notice to every user
sub notice_all {
    my ($channel, $what, $ignore) = @_;
    foreach my $user (@{$channel->{users}}) {
        next unless $user->is_local;
        next if defined $ignore && $ignore == $user;
        $user->send(":".gv('SERVER', 'name')." NOTICE $$channel{name} :*** $what");
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

# take the lower time of a channel and unset higher time stuff
sub take_lower_time {
    my ($channel, $time) = @_;
    return if $time >= $channel->{time}; # never take a time that isn't lower
    log2("locally resetting $$channel{name} time to $time");
    my $amount = $channel->{time} - $time;
    $channel->set_time($time);

    # unset all channel modes
    my $modestring = ($channel->mode_string_all(gv('SERVER')))[0];
    $modestring =~ s/\+/\-/;
    notice_all($channel, "channel TS set back $amount seconds");
    send_all($channel, ":".gv('SERVER', 'name')." MODE $$channel{name} $modestring");
    $channel->{modes} = {};
}

# returns the highest prefix a user has
sub prefix {
    my ($channel, $user) = @_;
    return
      $channel->list_has('owner',  $user) ? $prefix{owner}  :
      $channel->list_has('admin',  $user) ? $prefix{admin}  :
      $channel->list_has('op',     $user) ? $prefix{op}     :
      $channel->list_has('halfop', $user) ? $prefix{halfop} :
      $channel->list_has('voice',  $user) ? $prefix{voice}  : q..;
}

1
