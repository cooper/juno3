#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::mine;

use warnings;
use strict;
use utils qw[log2 col];

our %commands = ();

# register command handlers
sub register_handler {
    my ($source, $command) = (shift, uc shift);

    # does it already exist?
    if (exists $commands{$command}) {
        log2("attempted to register $command which already exists");
        return
    }

    my ($params, $forward) = (shift, shift);

    # ensure that it is CODE
    my $ref = shift;
    if (ref $ref ne 'CODE') {
        log2("not a CODE reference for $command");
        return
    }

    # one per source
    if (exists $commands{$command}{$source}) {
        log2("$source already registered $command; aborting");
        return
    }

    #success
    $commands{$command}{$source} = {
        code    => $ref,
        params  => $params,
        forward => $forward,
        source  => $source
    };
    log2("$source registered $command");
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
        #if (uc $s[0] eq 'ERROR') {
        #    $server->{conn}->done(col(join ' ', @s[1..$#s]));
        #    return
        #}

        # server is ready for BURST
        if (uc $s[0] eq 'READY') {
            log2("sending burst to $$server{name}");
            send_burst($server);
            next
        }

        next unless defined $s[1];
        my $command = uc $s[1];


        if ($commands{$command}) { # an existing handler
            foreach my $source (keys %{$commands{$command}}) {
                send_children($server, $line) if $commands{$command}{$source}{forward};
                if ($#s >= $commands{$command}{$source}{params}) {
                    $commands{$command}{$source}{code}($server, $line, @s)
                }
                else {
                    log2("not enough parameters for $command");
                }
            }
        }

        # to make things prettier
        else {
            next
        }

    }
    return 1
}

sub send_burst {
    my $server = shift;

    if ($server->{i_sent_burst}) {
        log2("trying to send burst to a server we have already sent burst to?!");
        return
    }

    $server->sendme('BURST');

    # send MY user mode names
    foreach my $name (keys %{$utils::GV{server}->{umodes}}) {
        my $mode = $utils::GV{server}->umode_letter($name);
        $server->server::outgoing::addumode($utils::GV{server}, $name, $mode);
    }

    # send MY channel mode names
    foreach my $name (keys %{$utils::GV{server}->{cmodes}}) {
        my $mode = $utils::GV{server}->cmode_letter($name);
        my $type = $utils::GV{server}->cmode_type($name);
        $server->server::outgoing::addcmode($utils::GV{server}, $name, $mode, $type);
    }

    # child servers
    foreach my $serv (values %server::server) {
        # the server already knows of thse
        if ($server == $serv ||
          $serv == $utils::GV{server} || 
          $server->{sid} == $serv->{source}) {
            next
        }
        $server->server::outgoing::sid($serv);

        # send user modes of other servers names :)
        while (my ($name, $mode) = each %{$serv->{umodes}}) {
            $server->server::outgoing::addumode($serv, $name, $mode);
        }
    }

    # users
    foreach my $user (values %user::user) {
        # ignore users the server already knows!
        next if $user->{server} == $server || $server->{sid} == $user->{source};
        $server->server::outgoing::uid($user);

        # oper flags
        if (scalar @{$user->{flags}}) {
            $server->server::outgoing::oper($user, @{$user->{flags}});
        }

        # away reason
        if (exists $user->{away}) {
            $server->server::outgoing::away($user);
        }
    }

    # channels
    foreach my $channel (values %channel::channels) {
        foreach my $user (@{$channel->{users}}) {
            $server->server::outgoing::sjoin($user, $channel, $channel->{time});
        }

        # modes
        my $str = $channel->mode_string($utils::GV{server});
        if ($str && $str ne '+') {
            $server->server::outgoing::cmode($utils::GV{server}, $channel, $channel->{time}, $utils::GV{server}{sid}, $str);
        }
    }

    $server->sendme('ENDBURST');
    $server->{i_sent_burst} = 1;

    return 1
}

# send data to all of my children
sub send_children {
    my $ignore = shift;
    foreach my $server (values %server::server) {
        next unless $server->{conn};
        next if defined $ignore && $server == $ignore;
        $server->send(@_)
    }
    return 1
}

sub sendfrom_children {
    my $ignore = shift;
    foreach my $server (values %server::server) {
        next unless $server->{conn};
        next if defined $ignore && $server == $ignore;
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
