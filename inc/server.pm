#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server;

use warnings;
use strict;

use utils qw[log2];

our %server;

sub new {

    my ($class, $ref) = @_;

    # create the server object
    bless my $server = {}, $class;
    $server->{$_} = $ref->{$_} foreach qw[sid name proto ircd desc time];
    $server{$server->{sid}} = $server;
    log2("new server $$server{sid}:$$server{name} $$server{proto}-$$server{ircd} [$$server{desc}]");

    return $server

}

sub quit {
    my $server = shift;
    log2("server $$server{sid} has quit");
    delete $server{$server->{sid}};
}

sub handle {
    server::mine::handle(@_)
}

1
