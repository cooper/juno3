#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::mine;

use warnings;
use strict;
use utils qw[log2];

our %commands;

# handle local user data
sub handle {
    my $server = shift;
    foreach my $line (split "\n", shift) {

        my @s = split /\s+/, $line;

        # response to PINGs
        if (uc $s[0] eq 'PING') {
            $server->mine->send('PONG'.(defined $s[1] ? qq( $s[1]) : q..));
            next
        }

        if (uc $s[0] eq 'ERROR') {
            $server->{conn}->done(col(join ' ', @s[1..$#s]))
        }

        my $command = uc $s[1];

        if ($commands{$command}) { # an existing handler
            $commands{$command}{'sub'}($server, @s, $line);
        }

    }
    return 1
}

# send data to MY servers.
sub send {
    my $server = shift;
    if (!$server->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a unconnected server! please report this error by $sub. $$server{name}");
        return
    }
    $server->{conn}->send(@_)
}

1
