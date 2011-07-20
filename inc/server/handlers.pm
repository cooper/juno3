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
    BURST    => {
        params  => 0,
        forward => 1,
        code    => \&burst
    },
    ENDBURST    => {
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
    $user->handle_mode_string($ref->{modes});

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
    # TODO send to familiar users
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
    $user->handle_mode_string($args[2]);
}

sub privmsgnotice {
    my ($server, $data, @args) = @_;
    my $user    = user::lookup_by_id(col($args[0]));
    my $command = uc $args[1];

    # we can't  use @args because it splits by whitespace
    my @m = split ' ', $data, 4;
    my $message = col($m[3]);

    # is it a user?
    my $tuser = user::lookup_by_id(col($args[2]));
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
    # TODO
}

# join
sub sjoin {
    my ($server, $data, @args) = @_;
    my $user    = user::lookup_by_id(col($args[0]));
    my $chname  = uc $args[2];

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
    $channel->join($user, $time);

    # for each user in the channel
    foreach my $usr (@{$channel->{users}}) {
        next unless $usr->is_local;
        $usr->sendfrom($user->full, "JOIN $$channel{name}")
    }
}

1
