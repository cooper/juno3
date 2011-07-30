#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package channel::modes;

use warnings;
use strict;

use utils 'log2';

# constants
sub normal        () { 0 }
sub parameter     () { 1 }
sub parameter_set () { 2 }
sub list          () { 3 }
sub status        () { 4 }

my %blocks;

# local modes
# eventually this will all be in utils.pm # TODO
# types:
#   normal (0)
#   parameter (1)
#   parameter_set (2)
#   list (3)
#   status (4)
our %modes = (
    no_ext        => [normal,    'n'],
    protect_topic => [normal,    't'],
    moderated     => [normal,    'm'],
    testing       => [parameter, 'T'],
    owner         => [status,    'q'],
    admin         => [status,    'a'],
    op            => [status,    'o'],
    halfop        => [status,    'h'],
    voice         => [status,    'v']
);

# this just tells the internal server what
# mode is associated with what letter and type
sub add_internal_modes {
    my $server = shift;
    log2("registering internal channel modes");
    foreach my $name (keys %modes) {
        $server->add_cmode($name, $modes{$name}[1], $modes{$name}[0]);
    }
    log2("end of internal modes");
}

# register a block check to a mode
sub register_block {
    my ($name, $what, $code) = @_;
    if (ref $code ne 'CODE') {
        log2((caller)[0]." tried to register a block to $name that isn't CODE.");
        return
    }
    if (exists $blocks{$name}{$what}) {
        log2((caller)[0]." tried to register $what to $name which is already registered");
        return
    }
    log2("registered $what to $name");
    $blocks{$name}{$what} = $code;
    return 1
}

# TODO
sub fire {
    my ($channel, $server, $source, $state, $name, $parameter, $parameters, $force, $over_protocol) = @_;
    if (!exists $blocks{$name}) {
        # nothing to do
        return 1
    }
    my %this = (
        server => $server,
        source => $source,
        state  => $state,
        param  => $parameter,
        params => $parameters,
        force  => $force,
        proto  => $over_protocol
    );
    foreach my $block (values %{$blocks{$name}}) {
        return unless $block->($channel, \%this)
    }
    return 1
}

# blocks

log2("registering internal mode blocks");

# test mode
register_block('testing', 'internal', sub {
    my ($channel, $mode) = @_;
    push @{$mode->{params}}, $mode->{param};
    return 1
});

# channel bans
register_block('ban', 'internal', sub {
    my ($channel, $mode) = @_;
    if ($mode->{state}) {
        $channel->add_to_list('ban', $mode->{param});
    }
    else {
        $channel->remove_from_list('ban', $mode->{param});
    }
    push @{$mode->{params}}, $mode->{param};
});


# status modes

my %needs = (
    owner  => ['owner'],
    admin  => ['owner', 'admin'],
    op     => ['owner', 'admin', 'op'],
    halfop => ['owner', 'admin', 'op'],
    voice  => ['owner', 'admin', 'op', 'halfop']
);

foreach my $modename (keys %needs) {

    # registers the main mode stuff
    register_block($modename, 'internal', sub {
        my ($channel, $mode) = @_;
        my $source = $mode->{source};
        my $target = $mode->{proto} ? user::lookup_by_id($mode->{param}) : user::lookup_by_nick($mode->{param});

        # make sure the target user exists
        if (!$target) {
            if (!$mode->{force} && $source->isa('user') && $source->is_local) {
                $source->numeric('ERR_NOSUCHNICK', $mode->{param});
            }
            return
        }

        # and also make sure he is on the channel
        if (!$channel->has_user($target)) {
            if (!$mode->{force} && $source->isa('user') && $source->is_local) {
                $source->numeric('ERR_USERNOTINCHANNEL', $target->{nick}, $channel->{name});
            }
            return
        }

        if (!$mode->{force} && $source->is_local) {

            # for each need, check if the user has it
            my $check_needs = sub {
                foreach my $need (@{$needs{$modename}}) {
                    return 1 if $channel->list_has($need, $source);
                }
                return
            };

            # they don't have any of the needs
            return unless $check_needs->();

        }

        # [USER RESPONSE, SERVER RESPONSE]
        push @{$mode->{params}}, [$target->{nick}, $target->{uid}];
        my $do = $mode->{state} ? 'add_to_list' : 'remove_from_list';
        $channel->$do($modename, $target);
        return 1
    });

}

log2("end of internal mode blocks");

1
