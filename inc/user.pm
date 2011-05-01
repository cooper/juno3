#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user;

use warnings;
use strict;

use utils qw[log2];

# create a new user

sub new {

    my ($class, $ref) = @_;

    # create the user object
    bless my $user = {}, $class;
    $user->{$_} = $ref->{$_} foreach qw[nick ident real ssl uid];

    return $user

}

1
