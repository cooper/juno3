#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# TODO  channel::mine
package channel;

sub new {
    my ($class, $ref) = @_;
    bless my $channel = {}, $class;
    $channel->{$_}    = $ref->{$_} foreach qw/name time/;
    $channel->{users} = []; # array ref of user objects
}

1
