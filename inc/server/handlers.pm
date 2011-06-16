#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::handlers;

use warnings;
use strict;
use utils qw[col log2];

my %commands = (
    SID => {
        params  => 6,
        forward => 1,
        code    => \&sid
    },
    UID => {
        params  => 9,
        forward => 1,
        code    => \&uid
    },
    QUIT => {
        params  => 1,
        forward => 1,
        code    => \&quit
    }
);

server::mine::register_handler($_, $commands{$_}{params}, $commands{$_}{forward}, $commands{$_}{code}) foreach keys %commands;

sub sid {
    my ($server, $data, @args) = @_;

    my $ref        = {};
    $ref->{$_}     = shift @args foreach qw[parent dummy sid time name proto ircd];
    $ref->{desc}   = col(join ' ', @args);
    $ref->{source} = $server->{sid};
    $ref->{parent} = server::lookup_by_id(col($ref->{parent}));
    delete $ref->{dummy};

    # create a new server
    my $serv = server->new($ref);
    return 1
}

sub uid {
    my ($server, $data, @args) = @_;

    my $ref        = {};
    $ref->{$_}     = shift @args foreach qw[server dummy uid time modes nick ident host cloak ip];
    $ref->{real}   = col(join ' ', @args);
    $ref->{source} = $server->{sid};
    $ref->{server} = server::lookup_by_id(col($ref->{server}));
    delete $ref->{dummy};
    delete $ref->{modes}; # this will be an array ref later

    # nick collision?
    # TODO send the nick change to the user if it's local!
    my $used = user::lookup_by_nick($ref->{nick});
    if ($used) {
        log2("nick collision! $$ref{nick}");
        if ($ref->{time} > $used->{time}) {
            # I lose
            $ref->{nick} = $ref->{uid}
        }
        elsif ($ref->{time} < $used->{time}) {
            # you lose
            $used->change_nick($used->{uid})
        }
        elsif ($ref->{time} == $used->{time}) {
            # we both lose
            $ref->{nick} = $ref->{uid};
            $used->change_nick($used->{uid})
        }
    }

    # create a new user
    my $user = user->new($ref);
    return 1

}

sub quit {
    my ($server, $data, @args) = @_;

    # find the server or user
    my $source = utils::global_lookup(col($args[0]));

    # delete the server or user
    $source->quit(col(join ' ', @args[2..$#args]));
}

1
