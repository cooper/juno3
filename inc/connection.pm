#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

use utils qw[log2 col];

our ($id, %connection) = 0;

sub new {
    my ($this, $peer) = @_;

    bless my $connection = {
        obj => $peer,
        ip => $peer->peerhost,
        host => $peer->peerhost,
        id => ++$id
    }, $this;

    log2("Processing connection from $$connection{ip}");    
    $main::select->add($peer);
    return $connection{$peer} = $connection
}

sub handle {
    my ($connection, $data) = @_;

    # strip unwanted characters
    $data =~ s/(\n|\r|\0)//g;

    if (exists $connection->{ready}) {
        return #utils::lookup($connection)->handle ...
    }

    my @args = split /\s+/, $data;

    given (uc shift @args) {

        when ('NICK') {

            # set the nick
            if (defined ( my $nick = col(shift @args) )) {
                $connection->{nick} = $nick
            }

            # the user is ready if their USER info has been sent
            $connection->ready if exists $connection->{ident}

        }

        when ('USER') {

            # set ident and real name
            if (defined $args[3]) {
                $connection->{ident} = $args[0];
                $connection->{real} = col((split /\s+/, $data, 4)[3])
            }

            # not enough parameter
            else {
            }

            # the user is ready if their NICK has been sent
            $connection->ready if exists $connection->{nick}

        }

    }

    return 1

}

sub ready {
    my $connection = shift;

    # must be a user
    if (exists $connection->{nick}) {
        return user->new($connection)
    }

    # must be a server
    elsif (exists $connection->{name}) {
        return server->new($connection)
    }

    
    else {
        # must be an intergalactic alien
    }

    return $connection->{ready} = 1

}

# send data to the socket

sub send {
    return main::sendpeer(shift->{obj}, shift)
}

1
