# Copyright (c) 2012, Mitchell Cooper
package API::Base::ServerCommands;

use warnings;
use strict;

use utils 'log2';

sub register_server_command {
    my ($mod, %opts) = @_;

    # make sure all required options are present
    foreach my $what (qw|name code|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        log2("server command $opts{name} does not have '$what' option.");
        return
    }

    $mod->{user_commands} ||= [];

    # register to juno
    server::mine::register_handler(
        $mod->{name},
        $opts{name},
        $opts{parameters} || 0,
        $opts{forward} || 0,
        $opts{code}
    ) or return;

    push @{$mod->{server_commands}}, $opts{name};
    return 1
}

sub unload {
    my ($class, $mod) = @_;
    log2("unloading server commands registered by $$mod{name}");
    server::mine::delete_handler($_) foreach @{$mod->{server_commands}};
    log2("done unloading commands");
    return 1
}

1
