#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# TODO  channel::mine
package channel;

use warnings;
use strict;

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
# $channel->set_mode('ban', '*!*@google.com');
sub set_mode {
    my ($channel, $name, $parameter) = @_;
    return if $channel->is_mode($name);
    $channel->{modes}->{$name} = {
        parameter => $parameter,
        time      => time
    };
    log2("$$channel{name} +$name");
    return 1
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
    $channel->{time} = $time
}

# returns the mode string,
# or '+' if no changes were made.
sub handle_mode_string {
    my ($channel, $server, $source, $modestr, $force) = @_;
    log2("set $modestr on $$channel{name} from $$server{name}");

    # array reference passed to mode blocks and used in the return
    my $parameters = [];

    my $state = 1;
    my $str   = '+';
    my @m     = split /\s+/, $modestr;

    letter: foreach my $letter (split //, shift @m) {
        if ($letter eq '+') {
            $str .= '+' unless $state;
            $state = 1
        }
        elsif ($letter eq '-') {
            $str .= '-' if $state;
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
            my $win = $channel->channel::modes::fire($server, $source, $state, $name, $parameter, $parameters);
            if (!$force) {
                next unless $win
            }

            my $do = $state ? 'set_mode' : 'unset_mode';
            $channel->$do($name);
            $str .= $letter
        }
    }

    # it's easier to do this than it is to
    # keep track of them
    $str =~ s/\+\+/\+/g;
    $str =~ s/\-\-/\-/g; 
    $str =~ s/\+\-/\-/g;
    $str =~ s/\-\+/\+/g;

    log2("end of mode handle");
    return join ' ', $str, @$parameters
}

# returns a +modes string
sub mode_string {
    my ($channel, $server) = @_;
    my (@modes, @params);
    foreach my $name (keys %{$channel->{modes}}) {
        push @modes, $server->cmode_letter($name);
        if (my $param = $channel->{modes}->{$name}->{parameter}) {
            push @params, $param
        }
    }
    @modes = sort { $a cmp $b } @modes; # alphabetize
    return '+'.join(' ', join('', @modes), @params)
}

# TODO mode_string_all (includes list modes, status modes, etc.)

# find a channel by its name
sub lookup_by_name {
    my $name = lc shift;
    return $channels{$name}
}

1
