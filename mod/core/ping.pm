# Copyright (c) 2012, Mitchell Cooper
package ext::core::ping;

use warnings;
use strict;

use utils qw|gv col|;

our $mod = API::Module->new(
    name        => 'core/ping',
    version     => '0.1',
    description => 'ping the server',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'ping',
        description => 'ping the server',
        parameters  => 1,
        code        => \&ping
    )
}

sub ping {
    my ($user, $data, @s) = @_;
    $user->sendserv('PONG '.gv('SERVER', 'name').' :'.col($s[1]))
}

$mod
