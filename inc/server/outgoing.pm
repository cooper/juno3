#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# contains outgoing commands
package server::outgoing;

use warnings;
use strict;

sub quit_all {
    my ($connection, $reason) = @_;
    server::mine::sendfrom_children($connection->{type}->id, 'QUIT :'.$reason)
}

sub sid {
    my ($server, $serv) = @_;
    $server->sendfrom($serv->{parent}->{sid},
      "SID $$serv{sid} $$serv{time} $$serv{name} $$serv{proto} $$serv{ircd} :$$serv{desc}")
}

sub sid_all {
    my $serv = shift;
    server::mine::sendfrom_children($serv->{parent}->{sid},
      "SID $$serv{sid} $$serv{time} $$serv{name} $$serv{proto} $$serv{ircd} :$$serv{desc}")
}

sub uid {
    my ($server, $user) = @_;
    $server->sendfrom($user->{server}->{sid},
      "UID $$user{uid} $$user{time} + $$user{nick} $$user{ident} $$user{host} $$user{cloak} $$user{ip} :$$user{real}")
}

sub uid_all {
    my $user = shift;
    server::mine::sendfrom_children($user->{server}->{sid},
      "UID $$user{uid} $$user{time} + $$user{nick} $$user{ident} $$user{host} $$user{cloak} $$user{ip} :$$user{real}")
}

1
