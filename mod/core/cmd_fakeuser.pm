# Copyright (c) 2012, Mitchell Cooper
package ext::core::cmd_fakeuser;

use warnings;
use strict;

our $mod = API::Module->new(
    name        => 'core/cmd_fakeuser',
    version     => '0.1',
    description => 'fake user command',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'user',
        description => 'fake user command',
        code        => \&fake_user
    )
}

sub fake_user {
    my $user = shift;
    $user->numeric('ERR_ALREADYREGISTRED');
}

$mod
