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

sub addcmode {
    my ($server, $serv, $name, $mode) = @_;
    $server->sendfrom($serv->{sid}, "ADDCMODE $name $mode");
}

sub addcmode_all {
    my ($serv, $name, $mode) = @_;
    server::mine::sendfrom_children(undef, $serv->{sid}, "ADDCMODE $name $mode");
}


#########
# users #
#########

# new user

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

# nick change

sub nickchange {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, "NICK $$user{nick}")
}

sub nickchange_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, "NICK $$user{nick}")
}

# user mode change

sub umode {
    my ($server, $user, $modestr) = @_;
    $server->sendfrom($user->{uid}, "UMODE $modestr")
}

sub umode_all {
    my ($user, $modestr) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "UMODE $modestr")
}

# privmsg and notice

sub privmsgnotice {
    my ($server, $cmd, $user, $target, $message) = @_;
    $server->sendfrom($user->{uid}, "$cmd $target :$message")
}

sub privmsgnotice_all {
    my ($cmd, $user, $target, $message) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "$cmd $target :$message")
}

# channel join

sub join {
    my ($server, $user, $channel, $time) = @_;
    $server->sendfrom($user->{uid}, "JOIN $$channel{name} $time");
}

sub join_all {
    my ($user, $channel, $time) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "JOIN $$channel{name} $time");
}

# add oper flags

sub oper {
    my ($server, $user, @flags) = @_;
    $server->sendfrom($user->{uid}, "OPER @flags");
}

sub oper_all {
    my ($user, @flags) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "OPER @flags");
}

# set away

sub away {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, "AWAY :$$user{away}");
}

sub away_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, "AWAY :$$user{away}");
}

# return from away

sub return_away {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, 'RETURN');
}

sub return_away_all {
    my $user = shift;
    server::mine::sendfrom_children($user->{uid}, 'RETURN');
}

########
# both #
########

# channel mode change

sub cmode {
    my ($server, $source, $channel, $time, $perspective, $modestr) = @_;
    $server->sendfrom($source->id, "CMODE $$channel{name} $time $perspective :$modestr")
}

sub cmode_all {
    my ($source, $channel, $time, $perspective, $modestr) = @_;
    server::mine::send_from_children($source->id, "CMODE $$channel{name} $time $perspective :$modestr")
}

1
