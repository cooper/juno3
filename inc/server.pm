#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server;

use warnings;
use strict;

use utils qw[log2];

sub new {

    my ($class, $ref) = @_;

    # create the server object
    bless my $server = {}, $class;
    $server->{$_} = $ref->{$_} foreach qw[sid name proto ircd desc];

    log2("new server $$server{sid}:$$server{name} $$server{proto}-$$server{ircd} [$$server{desc}]");

    return $server

}

sub quit {
}

sub handle {
}

1
