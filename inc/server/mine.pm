#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::mine;

use warnings;
use strict;
use utils qw[log2];

our %commands = ();

# register command handlers
sub register_handler {
    my $command = uc shift;

    # does it already exist?
    if (exists $commands{$command}) {
        log2("attempted to register $command which already exists");
        return
    }

    my $params = shift;

    # ensure that it is CODE
    my $ref = shift;
    if (ref $ref ne 'CODE') {
        log2("not a CODE reference for $command");
        return
    }

    #success
    $commands{$command} = {
        code   => $ref,
        params => $params
    };
    log2((caller)[0]." registered $command");
    return 1
}

# handle local user data
sub handle {
    my $server = shift;
    foreach my $line (split "\n", shift) {

        my @s = split /\s+/, $line;

        # response to PINGs
        if (uc $s[0] eq 'PING') {
            $server->send('PONG'.(defined $s[1] ? qq( $s[1]) : q..));
            next
        }

        # end connection
        if (uc $s[0] eq 'ERROR') {
            $server->{conn}->done(col(join ' ', @s[1..$#s]));
            return
        }

        # server is ready for BURST
        if (uc $s[0] eq 'READY') {
            send_burst($server);
            next
        }

        my $command = uc $s[1];

        if ($commands{$command} and scalar @s >= $commands{$command}{params}) { # an existing handler
            $commands{$command}{code}($server, $line, @s);
        }

    }
    return 1
}

sub send_burst {
    my $server = shift;
    $server->sendme('BURST');

    # child servers
    foreach my $serv (values %server::server) {
        # the server already knows of thse
        if ($server == $serv ||
          $serv == $utils::GV{server} || 
          $server->{sid} == $serv->{source}) {
            next
        }
        $server->server::outgoing::sid($serv)
    }

    # users
    foreach my $user (values %user::user) {
        # ignore users the server already knows!
        next if $user->{server} == $server || $server->{sid} == $user->{source};
        $server->server::outgoing::uid($user)
    }

    $server->sendme('ENDBURST');
    return 1
}

# send data to all of my children
sub send_children {
    foreach my $server (keys %server::server) {
        next unless $server->{conn};
        $server->send(@_)
    }
    return 1
}

sub sendfrom_children {
    foreach my $server (values %server::server) {
        next unless $server->{conn};
        $server->sendfrom(@_)
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

# send data from ME

sub sendme {
    my $server = shift;
    $server->sendfrom($utils::GV{serverid}, @_)
}

# send data from a UID or SID
sub sendfrom {
    my ($server, $from) = (shift, shift);
    my @lines = ();
    foreach my $line (@_) {
        push @lines, ":$from $line"
    }
    $server->send(@lines)
}

1
