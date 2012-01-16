# Copyright (c) 2012, Mitchell Cooper
package ext::core_cmodes;
 
use warnings;
use strict;

my %cmodes = (
    ban => \&cmode_ban
);

our $mod = API::Module->new(
    name        => 'core/cmodes',
    version     => '0.1',
    description => 'the core set of channel modes',
    requires    => ['channel_modes'],
    initialize  => \&init
);
 
sub init {

    # register channel mode blocks
    $mod->register_channel_mode_block(
        name => $_,
        code => $cmodes{$_}
    ) || return foreach keys %cmodes;

    # register status channel modes
    register_statuses() or return;

    undef %cmodes;

    return 1
}


########################
# STATUS CHANNEL MODES #
########################

# status modes
sub register_statuses {
    my %needs = (
        owner  => ['owner'],
        admin  => ['owner', 'admin'],
        op     => ['owner', 'admin', 'op'],
        halfop => ['owner', 'admin', 'op'],
        voice  => ['owner', 'admin', 'op', 'halfop']
    );

    foreach my $modename (keys %needs) {
        $mod->register_channel_mode_block( name => $modename, code => sub {

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
        }) or return;
    }

    return 1
}

#################
# CHANNEL MODES #
#################

sub cmode_ban {
    my ($channel, $mode) = @_;
    if ($mode->{state}) {
        $channel->add_to_list('ban', $mode->{param});
    }
    else {
        $channel->remove_from_list('ban', $mode->{param});
    }
    push @{$mode->{params}}, $mode->{param};
    return 1
}

$mod
