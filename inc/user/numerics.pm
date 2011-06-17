#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::numerics;

use warnings;
use strict;

my %numerics = (
    RPL_WELCOME          => ['001', 'Welcome to the %s IRC Network %s!%s@%s'],
    ERR_ALREADYREGISTRED => ['461', ':You may not reregister']
);

user::mine::register_numeric($_, $numerics{$_}[0], $numerics{$_}[1]) foreach keys %numerics;

1
