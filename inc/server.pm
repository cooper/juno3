#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server;

use warnings;
use strict;
use feature 'switch';

use server::mine;
use server::linkage;
use server::handlers;
use server::outgoing;
use utils qw[log2];

our %server;

sub new {

    my ($class, $ref) = @_;

    # create the server object
    bless my $server = {}, $class;
    $server->{$_} = $ref->{$_} foreach qw[sid name proto ircd desc time parent source];

    $server->{umodes}       = {}; ################
    $server->{cmodes}       = {}; # named modes! #
                                  ################
    $server{$server->{sid}} = $server;
    log2("new server $$server{sid}:$$server{name} $$server{proto}-$$server{ircd} parent:$$server{parent}{name} [$$server{desc}]");

    return $server

}

sub quit {
    my ($server, $reason) = @_;

    log2("server $$server{name} has quit: $reason");

    # delete all of the server's users
    foreach my $user (values %user::user) {
        $user->quit('*.banana *.split') if $user->{server} == $server
    }

    log2("server $$server{name}'s data has been deleted.");

    delete $server{$server->{sid}};

    # now we must do the same for each of the servers' children and their children and so on
    foreach my $serv (values %server) {
        next if $serv == $server;
        $serv->quit('parent server has disconnected') if $serv->{parent} == $server
    }

    undef $server;
    return 1

}

# find by SID
sub lookup_by_id {
    my $sid = shift;
    return $server{$sid} if exists $server{$sid};
    return
}

# find by name
sub lookup_by_name {
    my $name = shift;
    foreach my $server (values %server) {
        return $server if lc $server->{name} eq $name
    }
    return
}

# add a user mode
sub add_umode {
    my ($server, $name, $mode) = @_;
    $server->{umodes}->{$name} = {
        letter => $mode
    };
    log2("$$server{name} registered $mode:$name");
    return 1
}

# umode letter to name
sub umode_name {
    my ($server, $mode) = @_;
    foreach my $name (keys %{$server->{umodes}}) {
        return $name if $mode eq $server->{umodes}->{$name}->{letter}
    }
    return
}

# umode name to letter
sub umode_letter {
    my ($server, $name) = @_;
    return $server->{umodes}->{$name}->{letter}
}

# add a channel mode
# types:
#   0: normal
#   1: parameter
#   2: parameter only when set
#   3: list
#   4: status
# I was gonna make a separate type for status modes but
# i don't if that's necessary
sub add_cmode {
    my ($server, $name, $mode, $type) = @_;
    $server->{cmodes}->{$name} = {
        letter => $mode,
        type   => $type
    };
    log2("$$server{name} registered $mode:$name");
    return 1
}

# cmode letter to name
sub cmode_name {
    my ($server, $mode) = @_;
    foreach my $name (keys %{$server->{cmodes}}) {
        return $name if $mode eq $server->{cmodes}->{$name}->{letter}
    }
    return
}

# cmode name to letter
sub cmode_letter {
    my ($server, $name) = @_;
    return $server->{cmodes}->{$name}->{letter}
}

# type
sub cmode_type {
    my ($server, $name) = @_;
    return $server->{cmodes}->{$name}->{type}
}

# change 1 server's mode string to another server's
sub convert_cmode_string {
    my ($server, $server2, $modestr) = @_;
    my $string = q..;
    my @m      = split / /, $modestr;

    foreach my $letter (split //, shift @m) {
        my $new = $letter;

        # translate it
        my $name = $server->cmode_name($letter);
        if ($name) { $new = $server2->cmode_letter($name) || $new }
        $string .= $new
    }

    my $newstring = join ' ', $string, @m;
    log2("converted \"$modestr\" to \"$newstring\"");
    return $newstring
}

# XXX mine.pm?
sub cmode_takes_parameter {
    my ($server, $name, $state) = @_;
    given ($server->{cmodes}->{$name}->{type}) {
        # always give a parameter
        when (1) {
            return 1
        }

        # only give a parameter when setting
        when (2) {
            return $state
        }

        # lists like +b always want a parameter
        # keep in mind that these view lists when there isn't one, though
        when (3) {
            return 1
        }

        # status modes always want a parameter
        when (4) {
            return 1
        }
    }

    # or give nothing
    return
}

sub is_local {
    return shift eq $utils::GV{server}
}

# returns an array of child servers
sub children {
    my $server = shift;
    my @children = ();
    foreach my $serv (values %server) {
        push @children, $serv if $serv->{parent} == $server
    }
    return @children
}

# local shortcuts
sub handle   { server::mine::handle(@_)   }
sub send     { server::mine::send(@_)     }
sub sendfrom { server::mine::sendfrom(@_) }
sub sendme   { server::mine::sendme(@_)   }

# other
sub id { shift->{sid} }


1

