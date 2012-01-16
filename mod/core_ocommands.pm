# Copyright (c) 2012, Mitchell Cooper
package ext::core_ocommands;
 
use warnings;
use strict;

our $mod = API::Module->new(
    name        => 'core/ocommands',
    version     => '0.1',
    description => 'the core set of outgoing commands',
    requires    => ['outgoing_commands'],
    initialize  => \&init
);
 
sub init {

    return 1
}

$mod
