#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::handlers;

use warnings;
use strict;
use utils qw[col];

my %commands = (
    UID => {
        params => 9,
        code   => \&uid
    },
    QUIT => {
        params => 1,
        code   => \&quit
    }
);

server::mine::register_handler($_, $commands{$_}{params}, $commands{$_}{code}) foreach keys %commands;

sub uid {
    my ($server, $data, @args) = @_;

    my $ref = {};
    $ref->{$_}     = shift @args foreach qw[server dummy uid time modes nick ident host cloak ip];
    $ref->{real}   = col(join ' ', @args);
    $ref->{server} = server::lookup_by_id(col($ref->{server}));
    delete $ref->{dummy};
    delete $ref->{modes}; # this will be an array ref later

    # create a new user
    my $user = user->new($ref);
    return 1

}

sub quit {
    my ($server, $data, @args) = @_;

    # find the server or user
    my $source = utils::global_lookup(col($args[0]));

    # delete the server or user
    $source->quit(col(join ' ', $args[2..$#args]));
}

1
