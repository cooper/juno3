# Copyright (c) 2012, Mitchell Cooper
package API::Base::ChannelModes;

use warnings;
use strict;

use utils 'log2';

sub register_channel_mode_block {
    my ($mod, %opts) = @_;

    # make sure all required options are present
    foreach my $what (qw|name code|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        log2("channel mode block $opts{name} does not have '$what' option.");
        return
    }

    # register the mode block
    channel::modes::register_block(
        $opts{name},
        $mod->{name},
        $opts{code}
    );

    $mod->{channel_modes} ||= [];
    push @{$mod->{user_modes}}, $opts{name};
    return 1
}

sub unload {
    my ($class, $mod) = @_;
    log2("unloading channel modes registered by $$mod{name}");

    # delete 1 at a time
    foreach my $name (@{$mod->{user_modes}}) {
        channel::modes::delete_block($name, $mod->{name});
    }

    log2("done unloading modes");
    return 1
}

1
