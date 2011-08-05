#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::linkage;

use warnings;
use strict;

use utils qw[conf log2];

# connect to a server in the configuration

sub connect_server {
    my $server = shift;

    unless (exists $utils::conf{connect}{$server}) {
        log2("Attempted to connect to nonexistent server: $server");
        return
    }

    my %serv = %{$utils::conf{connect}{$server}};

    # create the socket
    my $socket = $main::socket_class->new(
        PeerAddr => $serv{address},
        PeerPort => $serv{port},
        #Proto    => 'tcp'
    );

    if (!$socket) {
        log2("Could not connect to $server: ".($! ? $! : $@));
        return
    }

    log2("Connection established to $server");

    # add the socket to select
    my $connection = connection->new($socket);

    # send server credentials.
    main::sendpeer($socket,
        "SERVER $utils::GV{serverid} $utils::GV{servername} $main::PROTO $main::VERSION :$utils::GV{serverdesc}",
        "PASS $serv{send_password}"
    );

    $connection->{sent_creds} = 1;
    $connection->{want} = $server;

    return $connection

}

1
