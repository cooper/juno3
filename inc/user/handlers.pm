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
    },
    LUSERS => {
        params => 0,
        code   => \&lusers
    }, 
    MOTD => {
        params => 0,
        code   => \&motd
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

sub lusers {
    my $user = shift;
    my ($users, $invisible, $opers, $myclients, $myservers, $unknown) = 0;
    $invisible = $opers = $myclients = $myservers = $unknown = $users;

    foreach my $connection (values %connection::connection) {
        if (!exists $connection->{type}) {
            $unknown++;
            next
        }
        elsif ($connection->{type}->isa('server')) {
            $myservers++;
            next
        }
        elsif ($connection->{type}->isa('user')) {
            $myclients++;
            next
        }
        else {
            $unknown++
        }
    }

    foreach my $usr (values %user::user) {
        # TODO opers
        # TODO invisible
        $users++
    }

    $user->numeric('RPL_LUSERCLIENT', $users, $invisible, scalar keys %server::server);
    $user->numeric('RPL_LUSEROP', $opers) if $opers;
    # TODO RPL_LUSERCHANNELS
    $user->numeric('RPL_LUSERME', $myclients, $myservers);
}

sub motd {
    # TODO <server> parameter
    my $user = shift;
    if (!defined $utils::GV{motd}) {
        $user->numeric('ERR_NOMOTD');
        return
    }
    $user->numeric('RPL_MOTDSTART', $utils::GV{servername});
    foreach my $line (@{$utils::GV{motd}}) {
        $user->numeric('RPL_MOTD', $line)
    }
    $user->numeric('RPL_ENDOFMOTD');
    return 1
}

1
