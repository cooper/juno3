#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

my $id = 0;

sub new {
    my ($this, $peer) = @_;
    bless my $connection = {
        obj => $peer,
        ip => $peer->peerhost,
        host => $peer->peerhost,
        id => ++$id
    }, $this;
    return $connection
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
            if (defined ( my $nick = shift @args )) {
                $connection->{nick} = $nick
            }

            # the user is ready if their USER info has been sent
            if ($connection->{user}) {
                $connection->ready
            }

        }

        when ('USER') {
            if (!defined $args[3]) {
             #   $connection->
            }
        }

    }

}

sub ready {
    my $connection = shift;

    # must be a user
    if (exists $connection->{nick}) {
        user->new($connection)
    }

    # must be a server
    elsif (exists $connection->{name}) {
        server->new($connection)
    }

    
    else {
        # must be an intergalactic alien
    }

}

# send data to the socket

sub send {
    return main::sendpeer(shift->{obj}, shift)
}

1
