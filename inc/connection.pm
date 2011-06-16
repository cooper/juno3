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
    if (conf qw/enabled resolve/) {
        resolve_hostname($connection)
    }
    else {
        $connection->{host} = $connection->{ip}
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

# RESOLVING FUNCTIONS

sub resolve_finish {
    my ($connection, $host) = @_;
    log2("$$connection{ip} has been set to $host");
    $connection->{host} = $host;
    $connection->ready if $connection->somewhat_ready;
    return 1
}

sub resolve_hostname {
    my $connection = shift;
    my $res = Net::DNS::Resolver->new;
    my $bg = $res->bgsend($connection->{ip}, 'PTR');
    main::register_loop('PTR lookup for '.$connection->{ip}, sub {
        resolve_ptr(shift, $res, $bg, $connection);
    });
}

sub resolve_ptr {
    my ($loop, $res, $bg, $connection) = @_;
    return unless $res->bgisready($bg);
    my $packet = $res->bgread($bg);
    undef $bg;
    if (!defined $packet) {
        # error
        main::delete_loop($loop);
        $connection->resolve_finish($connection->{ip});
        return
    }

    # no error; keep going
    my @rr = $packet->answer;

    # check if there is 1 record - no less, no more
    if (scalar @rr != 1) {
        main::delete_loop($loop);
        $connection->resolve_finish($connection->{ip});
        return
    }

    # found an rDNS. now check if it resolves to the IP address
    my $result = $rr[0]->ptrdname;
    main::delete_loop($loop);
    my $type  = (Net::IP::ip_is_ipv6($connection->{ip}) ? 'AAAA' : 'A');
    my $check = $res->bgsend($result, $type);
    main::register_loop($type.' lookup for '.$result, sub {
        resolve_aaaaa(shift, $res, $check, $connection, $result)
    });

}

sub resolve_aaaaa {
    my ($loop, $res, $bg, $connection, $result) = @_;
    return unless $res->bgisready($bg);
    my $packet = $res->bgread($bg);
    undef $bg;
    if (!defined $packet) {
        # error
        main::delete_loop($loop);
        $connection->resolve_finish($connection->{ip});
        return
    }

    # no error; keep going
    my @rr = $packet->answer;

    # check if there is 1 record - no less, no more
    if (scalar @rr != 1) {
        main::delete_loop($loop);
        $connection->resolve_finish($connection->{ip});
        return
    }

    # only accept A and AA
    if (!$rr[0]->isa('Net::DNS::RR::A') && !$rr[0]->isa('Net::DNS::RR::AAAA')) {
        main::delete_loop($loop);
        $connection->resolve_finish($connection->{ip});
        return
    }

    my $addr = $rr[0]->address;
    my $ip   = $connection->{ip};

    # compress them if it is IPv6
    if (Net::IP::ip_is_ipv6($addr)) {
        $addr = Net::IP::ip_compress_address($addr, 6);
        $ip   = Net::IP::ip_compress_address($ip, 6);
    }

    # found a record, does it match the IP address?
    if ($addr eq $ip) {
        # they match! set their host to that domain
        main::delete_loop($loop);
        $connection->resolve_finish($result);
        return 1
    }

    # they don't match :(
    main::delete_loop($loop);
    $connection->resolve_finish($connection->{ip});
    return

}

1
