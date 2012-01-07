# Copyright (c) 2012, Mitchell Cooper
package ext::core::fakeuser;

use warnings;
use strict;

use utils qw|gv col|;

our $mod = API::Module->new(
    name        => 'core/fakeuser',
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
