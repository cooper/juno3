#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# TODO  channel::mine
package channel;

use warnings;
use strict;
use feature 'switch';

use channel::mine;
use channel::modes;
use utils qw/log2/;

our %channels;

sub new {
    my ($class, $ref) = @_;

    # create the channel object
    bless my $channel = {}, $class;
    $channel->{$_}    = $ref->{$_} foreach qw/name time/;
    $channel->{users} = []; # array ref of user objects
    $channel->{modes} = {}; # named modes

    # make sure it doesn't exist already
    if (exists $channels{lc($ref->{name})}) {
        log2("attempted to create channel that already exists: $$ref{name}");
        return
    }

    # add to the channel hash
    $channels{lc($ref->{name})} = $channel;
    log2("new channel $$ref{name} at $$ref{time}");

    return $channel
}

# named mode stuff

sub is_mode {
    my ($channel, $name) = @_;
    return exists $channel->{modes}->{$name}
}

sub unset_mode {
    my ($channel, $name) = @_;

    # is the channel set to this mode?
    if (!$channel->is_mode($name)) {
        log2("attempted to unset mode $name on that is not set on $$channel{name}; ignoring.")
    }

    # it is, so remove it
    delete $channel->{modes}->{$name};
    log2("$$channel{name} -$name");
    return 1
}

# set channel modes
# takes an optional parameter
# $channel->set_mode('moderated');
sub set_mode {
    my ($channel, $name, $parameter) = @_;
    $channel->{modes}->{$name} = {
        parameter => $parameter,
        time      => time
        # list for list modes and status
    };
    log2("$$channel{name} +$name");
    return 1
}

# list has something
sub list_has {
    my ($channel, $name, $what) = @_;
    return unless exists $channel->{modes}->{$name};
    return 1 if grep { $_ eq $what } @{$channel->{modes}->{$name}->{list}}
}

# adds something to a list mode (such as ban)
sub add_to_list {
    my ($channel, $name, $parameter) = @_;
    $channel->{modes}->{$name} = {
        time => time,
        list => []
    } unless exists $channel->{modes}->{$name};

    # no duplicates plz
    if ($channel->list_has($name, $parameter)) {
        return
    }

    log2("$$channel{name}: adding $parameter to $name list");
    push @{$channel->{modes}->{$name}->{list}}, $parameter;
    return 1
}

# removes something from a list
sub remove_from_list {
    my ($channel, $name, $what) = @_;
    return unless $channel->list_has($name, $what);

    my @old = @{$channel->{modes}->{$name}->{list}};
    my @new = grep { $_ ne $what } @old;
    $channel->{modes}->{$name}->{list} = \@new;
    log2("$$channel{name}: removing $what from $name list");
}

# user joins channel
sub cjoin {
    my ($channel, $user, $time) = @_;

    # the channel TS will change
    # if the join time is older than the channel time
    if ($time < $channel->{time}) {
        $channel->set_time($time);
    }

    log2("adding $$user{nick} to $$channel{name}");

    # add the user to the channel
    push @{$channel->{users}}, $user;

    return $channel->{time}

}

# remove a user
sub remove {
    my ($channel, $user) = @_;
    log2("removing $$user{nick} from $$channel{name}");
    my @new = grep { $_ != $user } @{$channel->{users}};
    $channel->{users} = \@new
    # TODO delete data if last user
    # TODO delete user's status
}

# user is on channel
sub has_user {
    my ($channel, $user) = @_;
    foreach my $usr (@{$channel->{users}}) {
        return 1 if $usr == $user
    }
    return
}

# set the channel time
sub set_time {
    my ($channel, $time) = @_;
    if ($time > $channel->{time}) {
        log2("warning: setting time to a lower time from $$channel{time} to $time");
    }
    $channel->{time} = $time
}

# returns the mode string,
# or '+' if no changes were made.
sub handle_mode_string {
    my ($channel, $server, $source, $modestr, $force, $over_protocol) = @_;
    log2("set $modestr on $$channel{name} from $$server{name}");

    # array reference passed to mode blocks and used in the return
    my $parameters = [];

    my $state = 1;
    my $str   = '+';
    my @m     = split /\s+/, $modestr;

    letter: foreach my $letter (split //, shift @m) {
        if ($letter eq '+') {
            $str  .= '+' unless $state;
            $state = 1
        }
        elsif ($letter eq '-') {
            $str  .= '-' if $state;
            $state = 0
        }
        else {
            my $name = $server->cmode_name($letter);
            if (!defined $name) {
                log2("unknown mode $letter!");
                next
            }
            my $parameter = undef;
            if ($server->cmode_takes_parameter($name, $state)) {
                $parameter = shift @m;
                next letter unless defined $parameter
            }

            # don't allow this mode to be changed if the test fails
            # *unless* force is provided.
            my $win = $channel->channel::modes::fire($server, $source, $state, $name, $parameter, $parameters, $force, $over_protocol);
            if (!$force) {
                next unless $win
            }

            # if it is just a normal mode, set it
            if ($server->cmode_type($name) == 0) {
                my $do = $state ? 'set_mode' : 'unset_mode';
                $channel->$do($name);
            }
            $str .= $letter
        }
    }

    # it's easier to do this than it is to
    # keep track of them
    $str =~ s/\+\+/\+/g;
    $str =~ s/\-\-/\-/g; 
    $str =~ s/\+\-/\-/g;
    $str =~ s/\-\+/\+/g;

    # make it change array refs to separate params for servers
    # [USER RESPONSE, SERVER RESPONSE]
    my @user_params;
    my @server_params;
    foreach my $param (@$parameters) {
        if (ref $param eq 'ARRAY') {
            push @user_params, $param->[0];
            push @server_params, $param->[1]
        }

        # not an array ref
        else {
            push @user_params, $param;
            push @server_params, $param
        }
    }

    my $user_string   = join ' ', $str, @user_params;
    my $server_string = join ' ', $str, @server_params;

    log2("end of mode handle");
    return ($user_string, $server_string)
}

# returns a +modes string
#   normal (0)
#   parameter (1)
#   parameter_set (2)
#   list (3)
#   status (4)
sub mode_string {
    my ($channel, $server) = @_;
    my (@modes, @params);
    foreach my $name (keys %{$channel->{modes}}) {
        given ($server->cmode_type($name)) {
            when (0) { }
            when (1) { }
            when (2) { }
            default  { next }
        }
        push @modes, $server->cmode_letter($name);
        if (my $param = $channel->{modes}->{$name}->{parameter}) {
            push @params, $param
        }
    }
    @modes = sort { $a cmp $b } @modes; # alphabetize
    return '+'.join(' ', join('', @modes), @params)
}

# includes ALL modes
# this is intended for servers, so it probably uses UIDs and stuff like that
sub mode_string_all {
    my ($channel, $server) = @_;
    my (@modes, @params);

    foreach my $name (keys %{$channel->{modes}}) {
        my $letter = $server->cmode_letter($name);
        given ($server->cmode_type($name)) {

            # modes with 0 or 1 parameters
            when ([0, 1, 2]) {
                push @modes, $letter;
                continue
            }

            # modes with ONE parameter
            when ([1, 2]) {
                push @params, $channel->{modes}->{$name}->{parameter}
            }

            # lists
            when (3) {
                foreach my $thing (@{$channel->{modes}->{$name}->{list}}) {
                    push @modes,  $letter;
                    push @params, $thing
                }
            }

            # lists of users
            when (4) {
                foreach my $user (@{$channel->{modes}->{$name}->{list}}) {
                    push @modes,  $letter;
                    push @params, $user->{uid}
                }
            }

            # idk
            default  { next }
        }
    }

    @modes = sort { $a cmp $b } @modes; # alphabetize

    my $string = '+'.join(' ', join('', @modes), @params);
    return $string
}

# find a channel by its name
sub lookup_by_name {
    my $name = lc shift;
    return $channels{$name}
}

1
