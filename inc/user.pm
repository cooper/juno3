#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user;

use warnings;
use strict;

use utils qw[log2];

our %user;
our @modes = qw/i o/;

# create a new user

sub new {

    my ($class, $ref) = @_;
    
    # create the user object
    bless my $user      = {}, $class;
    $user->{$_}         = $ref->{$_} foreach qw[nick ident real host ip ssl uid time server cloak source];
    $user->{modes}      = [];
    $user{$user->{uid}} = $user;\
    log2("new user from $$user{server}{name}: $$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}]");

    $user->set_modes($ref->{modes});

    return $user

}

sub is_mode {
    my ($user, $mode) = @_;
    $mode ~~ @{$user->{modes}}
}

sub unset_modes {
    # takes a string of one or more modes
    my ($user, $modes) = @_;

    foreach my $mode (split //, $modes) {

        # is the user set to this mode?
        if (!$user->is_mode($mode)) {
            log2("attempted to unset mode $mode on that is not set on $$user{nick}; ignoring.")
        }

        # it does, so remove it
        @{$user->{modes}} = grep { $_ ne $mode } @{$user->{modes}}

    }

    return join '', @{$user->{modes}}
}

sub set_modes {
    # takes a string of one or more modes
    my ($user, $modes) = @_;

    foreach my $mode (split //, $modes) {

        # does it exist? no
        if (!($mode ~~ @modes)) {
            log2("attempted to set nonexistent mode $mode on $$user{nick}; ignoring.")
        }

        # it does
        push @{$user->{modes}}, $mode
    }

    return join '', @{$user->{modes}}
}

sub quit {
    # TODO don't forget to send QUIT to the user if it's local
    my ($user, $reason) = @_;
    log2("user quit from $$user{server}{name} uid:$$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}] ($reason)");
    delete $user{$user->{uid}};
}

sub change_nick {
    my ($user, $newnick) = @_;

    # make sure it doesn't exist first
    if (lookup_by_nick($newnick)) {
        log2("attempted to change nicks to a nickname that already exists! $newnick");
        return
    }

    log2("$$user{nick} -> $newnick");
    $user->{nick} = $newnick
}

# lookup functions

sub lookup_by_nick {
    my $nick = lc shift;
    foreach my $user (values %user) {
        return $user if lc $user->{nick} eq $nick
    }
    return
}

sub lookup_by_id {
    my $uid = shift;
    return $user{$uid} if exists $user{$uid};
    return
}

sub is_local {
    my $user = shift;
    return 1 if $user->{server}->{sid} == $utils::GV{sid};
    return
}

sub full {
    my $user = shift;
    "$$user{nick}!$$user{ident}\@$$user{host}"
}

# local shortcuts

sub handle   { user::mine::handle(@_)   }
sub send     { user::mine::send(@_)     }
sub sendfrom { user::mine::sendfrom(@_) }
sub sendserv { user::mine::sendserv(@_) }
sub numeric  { user::mine::numeric(@_)  }
sub id       { shift->{uid}             }

1
