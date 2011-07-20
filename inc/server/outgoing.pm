#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# contains outgoing commands
package server::outgoing;

use warnings;
use strict;

###########
# servers #
###########

sub quit_all {
    my ($connection, $reason) = @_;
    server::mine::sendfrom_children(undef, $connection->{type}->id, 'QUIT :'.$reason)
}

sub sid {
    my ($server, $serv) = @_;
    $server->sendfrom($serv->{parent}->{sid}, sprintf
        'SID %s %d %s %s %s :%s',
          $serv->{sid}, $serv->{time}, $serv->{name},
          $serv->{proto}, $serv->{ircd}, $serv->{desc})
}

sub sid_all {
    my $serv = shift;
    server::mine::sendfrom_children(undef, $serv->{parent}->{sid}, sprintf
        'SID %s %d %s %s %s :%s',
          $serv->{sid}, $serv->{time}, $serv->{name},
          $serv->{proto}, $serv->{ircd}, $serv->{desc})
}

sub addumode {
    my ($server, $serv, $name, $mode) = @_;
    $server->sendfrom($serv->{sid}, "ADDUMODE $name $mode");
}

sub addumode_all {
    my ($serv, $name, $mode) = @_;
    server::mine::sendfrom_children(undef, $serv->{sid}, "ADDUMODE $name $mode");
}

#########
# users #
#########

sub uid {
    my ($server, $user) = @_;
    $server->sendfrom($user->{server}->{sid}, sprintf
        'UID %s %d %s %s %s %s %s %s :%s',
          $user->{uid}, $user->{time}, $user->mode_string(),
          $user->{nick}, $user->{ident}, $user->{host},
          $user->{cloak}, $user->{ip}, $user->{real})
}

sub uid_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{server}->{sid}, sprintf
        'UID %s %d %s %s %s %s %s %s :%s',
          $user->{uid}, $user->{time}, $user->mode_string(),
          $user->{nick}, $user->{ident}, $user->{host},
          $user->{cloak}, $user->{ip}, $user->{real})
}

sub nickchange {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, "NICK $$user{nick}")
}

sub nickchange_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, "NICK $$user{nick}")
}

sub umode {
    my ($server, $user, $modestr) = @_;
    $server->sendfrom($user->{uid}, "UMODE $modestr")
}

sub umode_all {
    my ($user, $modestr) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "UMODE $modestr")
}

sub privmsgnotice {
    my ($server, $cmd, $user, $target, $message) = @_;
    $server->sendfrom($user->{uid}, "$cmd $target :$message")
}

sub privmsgnotice_all {
    my ($cmd, $user, $target, $message) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "$cmd $target :$message")
}

1
