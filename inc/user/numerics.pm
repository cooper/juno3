#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::numerics;

use warnings;
use strict;

my %numerics = (
    RPL_WELCOME          => ['001', 'Welcome to the %s IRC Network %s!%s@%s'],
    RPL_YOURHOST         => ['002', ':Your host is %s, running version %s'],
    RPL_CREATED          => ['003', ':This server was created %s'],
    RPL_MYINFO           => ['004', '%s %s %s %s'],
    RPL_ISUPPORT         => ['005', '%s'], # TODO
    RPL_LUSERCLIENT      => ['251', ':There are %d users and %d invisible on %d servers'],
    RPL_LUSEROP          => ['252', '%d :operators online'], # non-zero
    RPL_LUSERCHANNELS    => ['254', '%d :channels formed'], # TODO non-zero
    RPL_LUSERME          => ['255', 'I have %d clients and %d servers'],
    RPL_MOTD             => ['372', ':- %s'],
    RPL_MOTDSTART        => ['375', ':%s message of the day'],
    RPL_ENDOFMOTD        => ['376', ':End of message of the day'],
    ERR_UNKNOWNCOMMAND   => ['421', '%s :Unknown command'],
    ERR_NOMOTD           => ['422', ':MOTD file is missing'],
    ERR_NEEDMOREPARAMS   => ['461', '%s :Not enough parameters'],
    ERR_ALREADYREGISTRED => ['462', ':You may not reregister']
);

user::mine::register_numeric($_, $numerics{$_}[0], $numerics{$_}[1]) foreach keys %numerics;

1

