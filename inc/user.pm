#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user;

use warnings;
use strict;

use utils qw[log2];

our %user;

# create a new user

sub new {

    my ($class, $ref) = @_;
    
    # create the user object
    bless my $user      = {}, $class;
    $user->{$_}         = $ref->{$_} foreach qw[nick ident real host ip ssl uid time server cloak source];
    $user->{modes}      = []; # named modes!
    $user{$user->{uid}} = $user;
    log2("new user from $$user{server}{name}: $$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}]");

    # XXX $user->set_mode($ref->{modes});

    return $user

}

# named mode stuff

sub is_mode {
    my ($user, $mode) = @_;
    $mode ~~ @{$user->{modes}}
}

sub unset_mode {
    my ($user, $name) = @_;

    # is the user set to this mode?
    if (!$user->is_mode($name)) {
        log2("attempted to unset mode $name on that is not set on $$user{nick}; ignoring.")
    }

    # he is, so remove it
    log2("$$user{nick} -$name");
    @{$user->{modes}} = grep { $_ ne $name } @{$user->{modes}}

}

sub set_mode {
    my ($user, $name) = @_;
    return if $user->is_mode($name);
    log2("$$user{nick} +$name");
    push @{$user->{modes}}, $name
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

# handle a mode string and convert the mode letters to their mode
# names by searching the user's server's modes. returns the mode
# string, or '+' if no changes were made.
sub handle_mode_string {
    my ($user, $modestr) = @_;
    log2("set $modestr on $$user{nick}");
    my $state = 1;
    my $str   = '';
    foreach my $letter (split //, $modestr) {
        if ($letter eq '+') {
            $str .= '+' unless $state;
            $state = 1
        }
        elsif ($letter eq '-') {
            $str .= '-' if $state;
            $state = 0
        }
        else {
            my $name = $user->{server}->umode_name($letter);
            if (!defined $name) {
                log2("unknown mode $letter!");
                next
            }

            # ignore stupid mode changes
            if ($state && $user->is_mode($name) ||
              !$state && !$user->is_mode($name)) {
                next
            }
            my $do   = $state ? 'set_mode' : 'unset_mode';
            $user->$do($name);
            $str .= $letter
        }
    }
    $str =~ s/\+\-/\-/g; # it happens sometimes.
    log2("end of mode handle");
    return $str
}

# returns a +modes string
sub mode_string {
    my $user = shift;
    my $string = '+';
    foreach my $name (@{$user->{modes}}) {
        $string .= $user->{server}->umode_letter($name)
    }
    return $string
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
