#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::linkage;

use warnings;
use strict;

use utils qw[conf log2 gv];

# connect to a server in the configuration

sub connect_server {
    my $server = shift;

    unless (exists $utils::conf{connect}{$server}) {
        log2("Attempted to connect to nonexistent server: $server");
        return
    }

    my %serv = %{$utils::conf{connect}{$server}};

    # create the socket
    my $socket = IO::Socket::IP->new(
        PeerAddr => $serv{address},
        PeerPort => $serv{port},
        Proto    => 'tcp'
    );

    if (!$socket) {
        log2("Could not connect to $server: ".($! ? $! : $@));
        return
    }

    log2("Connection established to $server");

    my $stream = IO::Async::Stream->new(
        read_handle  => $socket,
        write_handle => $socket
    );

    # create connection object 
    my $conn = connection->new($stream);

    $stream->configure(
        read_all       => 0,
        read_len       => POSIX::BUFSIZ,
        on_read        => \&main::handle_data,
        on_read_eof    => sub { $conn->done('connection closed')   },
        on_read_error  => sub { $conn->done('read error: ' .$_[1]) },
        on_write_error => sub { $conn->done('write error: '.$_[1]) }
    );

    $main::loop->add($stream);

    # send server credentials.
    $conn->send(sprintf('SERVER %s %s %s %s :%s',
                        gv('SERVER', 'sid'),
                        gv('SERVER', 'name'),
                        gv('PROTO'),
                        gv('VERSION'),
                        gv('SERVER', 'desc')
    ));

    $conn->send("PASS $serv{send_password}");

    $conn->{sent_creds} = 1;
    $conn->{want}       = $server;

    return $conn

}

1
