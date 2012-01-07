# Copyright (c) 2012, Mitchell Cooper
package API::Base::UserCommands;

use warnings;
use strict;

sub register_user_command {
    my ($mod, %opts) = @_;

    # make sure all required options are present
    foreach my $what (qw|name description code|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        log2("user command $opts{name} does not have '$what' option.");
        return
    }

    # register to juno
    user::mine::register_handler(
        $mod->{name},
        $opts{name},
        $opts{parameters} || 0,
        $opts{code},
        $opts{description}
    );

    return 1
}

sub unload {
    my ($class, $mod) = @_;
}

1
