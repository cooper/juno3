#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# TODO  channel::mine
package channel;

use warnings;
use strict;

our %channels;

sub new {
    my ($class, $ref) = @_;

    # create the channel object
    bless my $channel = {}, $class;
    $channel->{$_}    = $ref->{$_} foreach qw/name time/;
    $channel->{users} = []; # array ref of user objects

    # add to the channel hash
    $channels{lc($ref->{name})} = $channel;

    return $channel
}

# user joins channel
sub join {
    my ($channel, $user, $time) = @_;

    # the channel TS will change
    # if the join time is older than the channel time
    if ($time < $channel->{time}) {
        $channel->set_time($time);
    }

    # add the user to the channel
    push @{$channel->{users}}, $user;

    return $channel->{time}

}

# set the channel time
sub set_time {
    my ($channel, $time) = @_;
    $channel->{time} = $time
}

1
