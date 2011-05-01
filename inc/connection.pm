#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

use utils qw[log2 col conn];

our ($uid, %connection) = 0;

sub new {
    my ($this, $peer) = @_;

    bless my $connection = {
        obj => $peer,
        ip => $peer->peerhost,
        host => $peer->peerhost
    }, $this;

    log2("Processing connection from $$connection{ip}");    
    $main::select->add($peer);
    return $connection{$peer} = $connection
}

sub handle {
    my ($connection, $data) = @_;

    # strip unwanted characters
    $data =~ s/(\n|\r|\0)//g;

    # if this peer is registered, forward the data to server or user
    return $connection->{type}->handle($data) if $connection->{ready};

    my @args = split /\s+/, $data;

    given (uc shift @args) {

        when ('NICK') {

            # not enough parameters
            return $connection->wrong_par('NICK') if not defined $args[0];

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

            # not enough parameters
            else {
                return $connection->wrong_par('USER')
            }

            # the user is ready if their NICK has been sent
            $connection->ready if exists $connection->{nick}

        }

        when ('SERVER') {

            # parameter check
            return $connection->wrong_par('SERVER') if not defined $args[4];


            $connection->{$_} = shift @args foreach qw[sid name proto ircd];

            # find a matching server

            if (defined ( my $addr = conn($connection->{name}, 'addr') )) {

                # check for matching IPs

                if ($connection->{ip} ne $addr) {
                    $connection->done('Invalid credentials');
                    return
                }

            }

            # no such server

            else {
                $connection->done('Invalid credentials');
                return
            }

            # if a password has been sent, it's ready
            $connection->ready if exists $connection->{pass}

        }

        when ('PASS') {

            # parameter check
            return $connection->wrong_par('PASS') if not defined $args[0];

            $connection->{pass} = shift @args;

            # if a server has been sent, it's ready
            $connection->ready if exists $connection->{name}

        }

    }

    return 1

}

# post-registration

sub wrong_par {
    my ($connection, $cmd) = @_;
    $connection->send(':'.$utils::GV{servername}.' 461 '
      .($connection->{nick} ? $connection->{nick} : '*').
      " $cmd :Not enough parameters");
    return
}

sub ready {
    my $connection = shift;

    # must be a user
    if (exists $connection->{nick}) {
        $connection->{ssl} = $connection->{obj}->isa('IO::Socket::SSL');
        $connection->{uid} = $utils::GV{serverid}.++$uid;
        $connection->{type} = user->new($connection)
    }

    # must be a server
    elsif (exists $connection->{name}) {

        # check for valid password.
        my $password;

        given (conn($connection->{name}, 'encryption')) {
            when ('sha1') { $password = Digest::SHA::sha1_hex($connection->{pass}) }
            when ('sha256') { $password = Digest::SHA::sha256_hex($connection->{pass}) }
            when ('sha512') { $password = Digest::SHA::sha512_hex($connection->{pass}) }
        }

        if ($password ne conn($connection->{name}, 'password')) {
            $connection->done('Invalid credentials');
            return
        }

        $connection->{type} = server->new($connection)
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

# find by a user or server object

sub lookup {

    my $obj = shift;

    foreach my $conn (values %connection) {

        # found a match
        return $conn if $conn->{type} == $obj

    }

    # no matches
    return

}

# end a connection

sub done {

    my ($connection, $reason) = @_;

    log2("Closing connection from $$connection{ip}: $reason");

    # tell user.pm or server.pm that the connection is closed
    $connection->{type}->quit($reason);

    # remove from connection list
    delete $connection{$connection->{obj}};

    # close socket, remvoe from IO::Select
    syswrite $connection->{obj}, "ERROR :Closing Link: $$connection{ip} ($reason)\r\n", POSIX::BUFSIZ, 0;
    $main::select->remove($connection->{obj});
    $connection->{obj}->close;

    undef $connection;
    return 1

}

1
