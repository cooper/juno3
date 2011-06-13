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
    bless my $user = {}, $class;
    $user->{$_} = $ref->{$_} foreach qw[nick ident real host ip ssl uid time];
    $user{$user->{uid}} = $user;
    log2("new user $$user{uid} $$user{nick}!$$user{ident}\@$$user{host} [$$user{real}]");

    return $user

}

sub handle {
    user::mine::handle(@_)
}

sub quit {
    # TODO don't forget to send QUIT to the user if it's local
    my $user = shift;
    delete $user{$user->{uid}};
}

# lookup functions
sub lookupbynick {
    my $nick = lc shift;
    foreach my $user (values %user) {
        return $user if lc $user->{nick} eq $nick
    }
    return
}

1
