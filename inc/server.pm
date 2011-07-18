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
    $server->{$_} = $ref->{$_} foreach qw[sid name proto ircd desc time parent source];

    $server->{umodes}       = {}; ################
    $server->{chmodes}      = {}; # named modes! #
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


# add a user mode
sub add_umode {
    my ($server, $name, $mode) = @_;
    $server->{umodes}->{$name} = $mode;
    log2("$$server{name} registered $mode:$name");
    return 1
}

# umode letter to name
sub umode_name {
    my ($server, $mode) = @_;
    while (my ($key, $val) = each %{$server->{umodes}}) {
        return $key if $mode eq $val
    }
    return
}

# umode name to letter
sub umode_letter {
    my ($server, $name) = @_;
    return $server->{umodes}->{$name}
}

# local shortcuts
sub handle   { server::mine::handle(@_)   }
sub send     { server::mine::send(@_)     }
sub sendfrom { server::mine::sendfrom(@_) }
sub sendme   { server::mine::sendme(@_)   }

# other
sub id { shift->{sid} }


1

