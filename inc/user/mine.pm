#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# this handles local user input
package user::mine;

use warnings;
use strict;

use utils qw[col log2];

my %commands;

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

    # success
    $commands{$command} = {
        code    => $ref,
        params  => $params
    };
    log2((caller)[0]." registered $command");
    return 1
}

sub handle {
    my $user = shift;
    foreach my $line (split "\n", shift) {

        my @s = split /\s+/, $line;

        if ($s[0] =~ m/^:/) { # lazy way of deciding if there is a source provided
            shift @s
        }

        my $command = uc $s[0];

        if ($commands{$command} and scalar @s >= $commands{$command}{params}) { # an existing handler
            $commands{$command}{code}($user, $line, @s)
        }

    }
    return 1
}

sub send {
    my $user = shift;
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    $user->{conn}->send(@_)
}

# send data with a source
sub sendserv {
    my ($user, $source) = (shift, shift);
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    my @send = ();
    foreach my $line (@_) {
        push @send, ":$source $line"
    }
    $user->{conn}->send(@send)
}

# send data with this server as the source
sub sendserv {
    my $user = shift;
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    my @send = ();
    foreach my $line (@_) {
        push @send, ":$utils::GV{servername} $line"
    }
    $user->{conn}->send(@send)
}

1
