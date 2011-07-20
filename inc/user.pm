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
    $user->{$_}         = $ref->{$_} foreach qw[nick ident real host ip ssl uid time server cloak source location];
    $user->{modes}      = []; # named modes!
    $user{$user->{uid}} = $user;
    log2("new user from $$user{server}{name}: $$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}]");

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
    my ($user, $reason) = @_;
    log2("user quit from $$user{server}{name} uid:$$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}] ($reason)");

    my %sent = ( $user => 1 );
    $user->sendfrom($user->full, "QUIT :$reason") if $user->is_local;

    # search for local users that know this client
    # and send the quit to them.

    # XXX y u no mine.pm
    foreach my $channel (values %channel::channels) {
        next unless $channel->has_user($user);
        $channel->remove($user);
        foreach my $usr (@{$channel->{users}}) {
            next unless $usr->is_local;
            next if $sent{$usr};
            $usr->sendfrom($user->full, "QUIT :$reason");
            $sent{$usr} = 1
        }
    }

    delete $user{$user->{uid}};
    undef $user;
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
    my $str   = '+';
    letter: foreach my $letter (split //, $modestr) {
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

            # don't allow this mode to be changed if the test fails
            foreach my $code (@{$user->{server}->{umode_tests}->{$name}}) {
                next letter unless $code->()
            }

            my $do   = $state ? 'set_mode' : 'unset_mode';
            $user->$do($name);
            $str .= $letter
        }
    }

    # it's easier to do this than it is to
    # keep track of them
    $str =~ s/\+\+/\+/g;
    $str =~ s/\-\-/\-/g; 
    $str =~ s/\+\-/\-/g;
    $str =~ s/\-\+/\+/g;

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
    return shift->{server} == $utils::GV{server}
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
