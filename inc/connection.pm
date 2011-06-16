#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

use utils qw[log2 col conn conf];

our ($ID, %connection) = 0;

sub new {
    my ($this, $peer) = @_;

    bless my $connection = {
        obj           => $peer,
        ip            => $peer->peerhost,
        source        => $utils::GV{serverid},
        last_ping     => time,
        time          => time,
        last_response => time
    }, $this;

    # resolve hostname
    resolve_hostname($connection) if conf qw/enabled resolve/;

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
                $connection->send(":$utils::GV{servername} 432 * $nick :Erroneous Nickname");
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
            $connection->ready if exists $connection->{pass} && exists $connection->{host}

        }

        when ('PASS') {

            # parameter check
            return $connection->wrong_par('PASS') if not defined $args[0];

            $connection->{pass} = shift @args;

            # if a server has been sent, it's ready
            $connection->ready if exists $connection->{name} && exists $connection->{host}

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
        $connection->{ssl}    = $connection->{obj}->isa('IO::Socket::SSL');
        $connection->{uid}    = $utils::GV{serverid}.++$ID;
        $connection->{server} = $utils::GV{server};
        $connection->{cloak}  = $connection->{host};
        $connection->{type}   = user->new($connection);
        # tell my children
        server::outgoing::uid_all($connection->{type})
    }

    # must be a server
    elsif (exists $connection->{name}) {

        # check for valid password.
        my $password;

        given (conn($connection->{name}, 'encryption')) {
            when ('sha1')   { $password = Digest::SHA::sha1_hex($connection->{pass})   }
            when ('sha256') { $password = Digest::SHA::sha256_hex($connection->{pass}) }
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
    undef $connection;
    return 1

}

sub resolve_hostname {
    my $connection = shift;
    my $res = Net::DNS::Resolver->new;
    my $bg = $res->bgsend($connection->{ip}, 'PTR');

    # ip-to-hostname check
    main::register_loop("IP-to-hostname for $$connection{ip}", sub {
        if ($res->bgisready($bg)) {
            my $packet = $res->bgread($bg);
            undef $bg;
            if (!defined $packet) {
                log2("there was an error resolving $$connection{ip}");
                $connection->{host} = $connection->{ip};
                $connection->ready if $connection->somewhat_ready;
                main::delete_loop(shift);
                return
            }
            foreach my $rr ($packet->answer) {
                my $resolution = $rr->ptrdname;
                log2("checking $$connection{ip} to match $resolution");
                my $check = $res->bgsend($resolution);

                # hostname-to-ip check
                main::register_loop("hostname-to-IP for $resolution", sub {
                    if ($res->bgisready($check)) {
                        my $packet = $res->bgread($check);
                        undef $check;
                        if (!defined $packet) {
                            log2("there was an error resolving $resolution");
                            $connection->{host} = $connection->{ip};
                            $connection->ready if $connection->somewhat_ready;
                            main::delete_loop(shift);
                            return
                        }
                        foreach my $rr ($packet->answer) {
                            if (!$rr->isa('Net::DNS::RR::A') && !$rr->isa('Net::DNS::RR:AAAA')) {
                                # this isn't an address!
                                next
                            }
                            if ($rr->address eq $connection->{ip}) {
                                # found a match!
                                $connection->{host} = $resolution;
                                log2("found a match: $$connection{ip} -> $resolution");
                                $connection->ready if $connection->somewhat_ready;
                                main::delete_loop(shift);
                                return 1
                            }
                        }
                        log2("no matches; using IP for $$connection{ip}");
                        $connection->{host} = $connection->{ip};
                        $connection->ready if $connection->somewhat_ready;
                        main::delete_loop(shift);
                    } # ha
                }); # ha!
 
            } # ...ha! ha!
            main::delete_loop(shift)
        } # ha
    });
    return
}

1
