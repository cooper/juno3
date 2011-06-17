#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::handlers;

use warnings;
use strict;
use utils qw[col log2];

my %commands = (
    PING => {
        params => 1,
        code   => \&ping
    },
    USER => {
        params => 0,
        code   => \&fake_user
    }
);

user::mine::register_handler($_, $commands{$_}{params}, $commands{$_}{code}) foreach keys %commands;

sub ping {
    my ($user, $data, @s) = @_;
    $user->sendserv("PONG $utils::GV{servername} :".col($s[1]))
}

sub fake_user {
    my $user = shift;
    $user->numeric('ERR_ALREADYREGISTRED');
}

1
