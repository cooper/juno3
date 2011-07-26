#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::handlers;

use warnings;
use strict;
use utils qw[col log2];

my %commands = (
    SID => {
        params  => 6,
        forward => 1,
        code    => \&sid
    },
    UID => {
        params  => 9,
        forward => 1,
        code    => \&uid
    },
    QUIT => {
        params  => 1,
        forward => 1,
        code    => \&quit
    },
    NICK => {
        params  => 1,
        forward => 1,
        code    => \&nick
    },
    BURST => {
        params  => 0,
        forward => 1,
        code    => \&burst
    },
    ENDBURST => {
        params  => 0,
        forward => 1,
        code    => \&endburst
    },
    ADDUMODE  => {
        params  => 2,
        forward => 1,
        code    => \&addumode
    },
    UMODE => {
        params  => 1,
        forward => 1,
        code    => \&umode
    },
    PRIVMSG => {
        params  => 2,
        forward => 0, # we have to figure ourself
        code    => \&privmsgnotice
    },
    NOTICE => {
        params  => 2,
        forward => 0, # we have to figure ourself
        code    => \&privmsgnotice
    },
    JOIN => {
        params  => 2,
        forward => 1,
        code    => \&sjoin
    },
    OPER => {
        params  => 1,
        forward => 1,
        code    => \&oper
    },
    AWAY => {
        params  => 1,
        forward => 1,
        code    => \&away
    },
    RETURN => {
        params  => 0,
        forward => 1,
        code    => \&return_away
    },
    ADDCMODE => {
        params  => 3,
        forward => 1,
        code    => \&addcmode
    },
    CMODE => {
        params  => 4,
        forward => 1,
        code    => \&cmode
    }
);

log2("registering core server handlers");
server::mine::register_handler('core', $_, $commands{$_}{params}, $commands{$_}{forward}, $commands{$_}{code}) foreach keys %commands;
log2("end of core handlers");

sub sid {
    my ($server, $data, @args) = @_;

    my $ref        = {};
    $ref->{$_}     = shift @args foreach qw[parent dummy sid time name proto ircd];
    $ref->{desc}   = col(join ' ', @args);
    $ref->{source} = $server->{sid};
    $ref->{parent} = server::lookup_by_id(col($ref->{parent}));
    delete $ref->{dummy};

    # create a new server
    my $serv = server->new($ref);
    return 1
}

sub uid {
    my ($server, $data, @args) = @_;

    my $ref          = {};
    $ref->{$_}       = shift @args foreach qw[server dummy uid time modes nick ident host cloak ip];
    $ref->{real}     = col(join ' ', @args);
    $ref->{source}   = $server->{sid};
    $ref->{location} = $server;
    $ref->{server}   = server::lookup_by_id(col($ref->{server}));
    delete $ref->{dummy};

    # nick collision?
    # TODO send the nick change to the user if it's local!
    my $used = user::lookup_by_nick($ref->{nick});
    if ($used) {
        log2("nick collision! $$ref{nick}");
        if ($ref->{time} > $used->{time}) {
            # I lose
            $ref->{nick} = $ref->{uid}
        }
        elsif ($ref->{time} < $used->{time}) {
            # you lose
            $used->change_nick($used->{uid})
        }
        else {
            # we both lose
            $ref->{nick} = $ref->{uid};
            $used->change_nick($used->{uid})
        }
    }

    # create a new user
    my $user = user->new($ref);

    # set modes
    $user->handle_mode_string($ref->{modes}, 1);

    return 1

}

sub quit {
    my ($server, $data, @args) = @_;

    # find the server or user
    my $source = utils::global_lookup(col($args[0]));

    # delete the server or user
    $source->quit(col(join ' ', @args[2..$#args]));
}

sub nick {
    # handle a nickchange
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));

    # tell ppl
    $user->channel::mine::send_all_user("NICK $args[2]");

    $user->change_nick($args[2])
}

sub burst {
    my $server = shift;
    $server->{is_burst} = 1;
    log2("$$server{name} is bursting information")
}

sub endburst {
    my $server = shift;
    delete $server->{is_burst};
    $server->{sent_burst} = 1;
    log2("end of burst from $$server{name}")
}

sub addumode {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    $serv->add_umode($args[2], $args[3]);
}

sub umode {
    # why would umodes need time stamps?
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->handle_mode_string($args[2], 1);
}

sub privmsgnotice {
    my ($server, $data, @args) = @_;
    my $user    = user::lookup_by_id(col($args[0]));
    my $command = uc $args[1];

    # we can't  use @args because it splits by whitespace
    my @m = split ' ', $data, 4;
    my $message = col($m[3]);

    # is it a user?
    my $tuser = user::lookup_by_id($args[2]);
    if ($tuser) {
        # if it's mine, send it
        if ($tuser->is_local) {
            $tuser->sendfrom($user->full, "$command $$tuser{nick} :$message");
            return 1
        }
        # otherwise pass this on...
        $tuser->{location}->server::outgoing::privmsgnotice($command, $user, $tuser->{uid}, $message);
        return 1
    }

    # must be a channel
    my $channel = channel::lookup_by_name($args[2]);
    if ($channel) {
        # tell local users
        $channel->channel::mine::send_all(':'.$user->full." $command $$channel{name} :$message", $user);

        # then tell local servers if necessary
        my %sent;
        foreach my $usr (values %user::user) {
            next if $server == $usr->{location};
            next if $usr->is_local;
            next if $sent{$usr->{location}};
            $sent{$usr->{location}} = 1;
            $usr->{location}->server::outgoing::privmsgnotice($command, $user, $channel->{name}, $message);
        }

        return 1
    }
}

# join
sub sjoin {
    my ($server, $data, @args) = @_;
    my $user    = user::lookup_by_id(col($args[0]));
    my $chname  = $args[2];

    # if the channel exists, just join
    my $channel = channel::lookup_by_name($chname);
    my $time = $args[3];

    # otherwise create a new one
    if (!$channel) {
        $channel = channel->new({
            name   => $chname,
            'time' => $time
        });
    }
    return if $channel->has_user($user);
    $channel->cjoin($user, $time);

    # for each user in the channel
    $channel->channel::mine::send_all(q(:).$user->full." JOIN $$channel{name}");
}

# add user flags
sub oper {
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->add_flags(@args[2..$#args]);
}

sub away {
    my ($server, $data, @args) = @_;
    my $user   = user::lookup_by_id(col($args[0]));
    my $reason = col((split /\s+/, $data, 3)[2]);
    $user->set_away($reason);
}

sub return_away {
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->return_away();
}

# add a channel mode
sub addcmode {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    $serv->add_cmode($args[2], $args[3], $args[4]);
}

# set a mode on a channel
sub cmode {
    my ($server, $data, @args) = @_;
    my $source      = utils::global_lookup(col($args[0]));
    my $channel     = channel::lookup_by_name($args[2]);
    my $perspective = server::lookup_by_id($args[4]);

    # take the lower time
    if ($args[3] < $channel->{time}) {
        $channel->set_time($args[3]);
    }

    my $result = $channel->handle_mode_string($perspective, $source, col(join ' ', @args[5..$#args]), 1);
    return 1 if !$result || $result =~ m/^(\+|\-)$/;

    # convert it to our view
    $result  = $perspective->convert_cmode_string($utils::GV{server}, $result);
    my $from = $source->isa('user') ? $source->full : $source->isa('server') ? $source->{name} : 'MagicalFairyPrincess';
    $channel->channel::mine::send_all(":$from MODE $$channel{name} $result");
}

1
