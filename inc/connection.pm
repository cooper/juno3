#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

use utils qw[log2 col conn conf match];

our ($ID, %connection) = 0;

sub new {
    my ($this, $peer) = @_;

    bless my $connection = {
        obj           => $peer,
        ip            => $peer->peerhost,
        source        => $utils::GV{serverid},
        ssl           => $peer->isa('IO::Socket::SSL'),
        last_ping     => time,
        time          => time,
        last_response => time
    }, $this;

    # resolve hostname
    if (conf qw/enabled resolve/) {
        $connection->send(':'.$utils::GV{servername}.' NOTICE * :*** Looking up your hostname...');
        res::resolve_hostname($connection)
    }
    else {
        $connection->{host} = $connection->{ip};
        $connection->send(':'.$utils::GV{servername}.' NOTICE * :*** hostname resolving is not enabled on this server')
    }

    log2("Processing connection from $$connection{ip}");    
    $main::select->add($peer);
    return $connection{$peer} = $connection
}

sub handle {
    my ($connection, $data) = @_;

    $connection->{ping_in_air}   = 0;
    $connection->{last_response} = time;

    # strip unwanted characters
    $data =~ s/(\n|\r|\0)//g;

    # if this peer is registered, forward the data to server or user
    return $connection->{type}->handle($data) if $connection->{ready};

    my @args = split /\s+/, $data;

    given (uc shift @args) {

        when ('NICK') {

            # not enough parameters
            return $connection->wrong_par('NICK') if not defined $args[0];

            my $nick = col(shift @args);

            # nick exists
            if (user::lookup_by_nick($nick)) {
                $connection->send(":$utils::GV{servername} 433 * $nick :Nickname is already in use.");
                return
            }

            # invalid chars
            if (!utils::validnick($nick)) {
                $connection->send(":$utils::GV{servername} 432 * $nick :Erroneous nickname");
                return
            }

            # set the nick
            $connection->{nick} = $nick;

            # the user is ready if their USER info has been sent
            $connection->ready if exists $connection->{ident} && exists $connection->{host}

        }

        when ('USER') {

            # set ident and real name
            if (defined $args[3]) {
                $connection->{ident} = $args[0];
                $connection->{real}  = col((split /\s+/, $data, 5)[4])
            }

            # not enough parameters
            else {
                return $connection->wrong_par('USER')
            }

            # the user is ready if their NICK has been sent
            $connection->ready if exists $connection->{nick} && exists $connection->{host}

        }

        when ('SERVER') {

            # parameter check
            return $connection->wrong_par('SERVER') if not defined $args[4];


            $connection->{$_}   = shift @args foreach qw[sid name proto ircd];
            $connection->{desc} = col(join ' ', @args);

            # find a matching server

            if (defined ( my $addr = conn($connection->{name}, 'address') )) {

                # check for matching IPs

                if (!match($connection->{ip}, $addr)) {
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
            $connection->ready if exists $connection->{pass} && exists $connection->{host}

        }

        when ('PASS') {

            # parameter check
            return $connection->wrong_par('PASS') if not defined $args[0];

            $connection->{pass} = shift @args;

            # if a server has been sent, it's ready
            $connection->ready if exists $connection->{name} && exists $connection->{host}

        }

        when ('QUIT') {
            my $reason = 'leaving';

            # get the reason if they specified one
            if (defined $args[1]) {
                $reason = col((split /\s+/,  $data, 2)[1])
            }

            $connection->done("Quit: $reason");
        }

    }
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
        $connection->{uid}      = $utils::GV{serverid}.++$ID;
        $connection->{server}   = $utils::GV{server};
        $connection->{location} = $utils::GV{server};
        $connection->{cloak}    = $connection->{host};
        $connection->{modes}    = '';
        $connection->{type}     = user->new($connection);

        # tell my children
        server::outgoing::uid_all($connection->{type})
    }

    # must be a server
    elsif (exists $connection->{name}) {

        # check for valid password.
        my $password;

        given (conn($connection->{name}, 'encryption')) {
            when ('sha1')   { $password = Digest::SHA::sha1_hex($connection->{pass})   }
            when ('sha224') { $password = Digest::SHA::sha224_hex($connection->{pass}) }
            when ('sha256') { $password = Digest::SHA::sha256_hex($connection->{pass}) }
            when ('sha384') { $password = Digest::SHA::sha384_hex($connection->{pass}) }
            when ('sha512') { $password = Digest::SHA::sha512_hex($connection->{pass}) }
            when ('md5')    { $password = Digest::MD5::md5_hex($connection->{pass})    }
        }

        if ($password ne conn($connection->{name}, 'receive_password')) {
            $connection->done('Invalid credentials');
            return
        }

        $connection->{parent} = $utils::GV{server};
        $connection->{type}   = server->new($connection);
        server::outgoing::sid_all($connection->{type});

        # send server credentials
        if (!$connection->{sent_creds}) {
            $connection->send("SERVER $utils::GV{serverid} $utils::GV{servername} $main::PROTO $main::VERSION :$utils::GV{serverdesc}");
            $connection->send('PASS '.conn($connection->{name}, 'send_password'))
        }

        $connection->send('READY');

    }

    
    else {
        # must be an intergalactic alien
    }
    
    $connection->{type}->{conn} = $connection;
    user::mine::new_connection($connection->{type}) if $connection->{type}->isa('user');
    return $connection->{ready} = 1

}

sub somewhat_ready {
    my $connection = shift;
    if (exists $connection->{nick} && exists $connection->{ident}) {
        return 1
    }
    if (exists $connection->{name} && exists $connection->{pass}) {
        return 1
    }
    return
}

# send data to the socket
sub send {
    return main::sendpeer(shift->{obj}, @_)
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

    if ($connection->{type}) {
        # share this quit with the children
        $connection->server::outgoing::quit_all($reason);

        # tell user.pm or server.pm that the connection is closed
        $connection->{type}->quit($reason)
    }

    # remove from connection list
    delete $connection{$connection->{obj}};

    # close socket, remove from IO::Select
    syswrite $connection->{obj}, "ERROR :Closing Link: $$connection{ip} ($reason)\r\n", POSIX::BUFSIZ, 0 unless eof $connection->{obj};
    $main::select->remove($connection->{obj});
    $connection->{obj}->close;
    undef $connection->{obj};
    undef $connection;
    return 1

}

1
