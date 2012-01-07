# Copyright (c) 2012, Mitchell Cooper
package ext::core::cmd_motd;

use warnings;
use strict;

use utils qw|gv col|;

our $mod = API::Module->new(
    name        => 'core/cmd_motd',
    version     => '0.1',
    description => 'display the message of the day',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'motd',
        description => 'display the message of the day',
        code        => \&motd
    )
}

sub motd {
    # TODO <server> parameter
    my $user = shift;
    if (!defined gv('MOTD')) {
        $user->numeric('ERR_NOMOTD');
        return
    }
    $user->numeric('RPL_MOTDSTART', gv('SERVER', 'name'));
    foreach my $line (@{gv('MOTD')}) {
        $user->numeric('RPL_MOTD', $line)
    }
    $user->numeric('RPL_ENDOFMOTD');
    return 1
}

$mod
