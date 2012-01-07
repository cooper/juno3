# Copyright (c) 2012, Mitchell Cooper
package ext::core::cmd_nick;

use warnings;
use strict;

use utils qw(col lceq);

our $mod = API::Module->new(
    name        => 'core/cmd_nick',
    version     => '0.1',
    description => 'change your nickname',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'nick',
        description => 'change your nickname',
        parameters  => 1,
        code        => \&nick
    )
}

sub nick {
    my ($user, $data, @args) = @_;
    my $newnick = col($args[1]);

    if ($newnick eq '0') {
        $newnick = $user->{uid}
    }
    else {
        # ignore stupid nick changes
        if (lceq $user->{nick} => $newnick) {
            return
        }

        # check for valid nick
        if (!utils::validnick($newnick)) {
            $user->numeric('ERR_ERRONEUSNICKNAME', $newnick);
            return
        }

        # check for existing nick
        if (user::lookup_by_nick($newnick)) {
            $user->numeric('ERR_NICKNAMEINUSE', $newnick);
            return
        }
    }

    # tell ppl
    $user->channel::mine::send_all_user("NICK $newnick");

    # change it
    $user->change_nick($newnick);

    server::outgoing::nickchange_all($user);
}

$mod
