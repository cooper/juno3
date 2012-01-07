# Copyright (c) 2012, Mitchell Cooper
package ext::core::cmd_fakecommands;

use warnings;
use strict;

our $mod = API::Module->new(
    name        => 'core/cmd_fakecommands',
    version     => '0.1',
    description => 'fake commands user and pong',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'user',
        description => 'fake user command',
        code        => \&fake_user
    );

    $mod->register_user_command(
        name        => 'pong',
        description => 'pong the server',
        code        => sub {}
    );

    return 1
}

sub fake_user {
    my $user = shift;
    $user->numeric('ERR_ALREADYREGISTRED');
}

$mod
