#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package server::handlers;

use warnings;
use strict;
use utils qw[col log2 gv];

{

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
    },
    PART => {
        params  => 1,
        forward => 1,
        code    => \&part
    },
    TOPIC => {
        params  => 3,
        forward => 1,
        code    => \&topic
    },

    # compact

    AUM => {
        params  => 1,
        forward => 1,
        code    => \&aum
    },
    ACM => {
        params  => 1,
        forward => 1,
        code    => \&acm
    },
    CUM => {
        params  => 4,
        forward => 1,
        code    => \&cum
    }
);

log2("registering core server handlers");
server::mine::register_handler('core', $_, $commands{$_}{params}, $commands{$_}{forward}, $commands{$_}{code}) foreach keys %commands;
log2("end of core handlers");
undef %commands;

}

sub sid {
    my ($server, $data, @args) = @_;

    my $ref        = {};
    $ref->{$_}     = shift @args foreach qw[parent dummy sid time name proto ircd];
    $ref->{desc}   = col(join ' ', @args);
    $ref->{source} = $server->{sid};
    $ref->{parent} = server::lookup_by_id(col($ref->{parent}));
    delete $ref->{dummy};

    # do not allow SID or server name collisions
    if (server::lookup_by_id($ref->{sid}) || server::lookup_by_name($ref->{name})) {
        log2("duplicate SID $$ref{sid} or server name $$ref{name}; dropping $$server{name}");
        $server->{conn}->done('attempted to introduce existing server');
        return
    }

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

    # uid collision?
    if (user::lookup_by_id($ref->{uid})) {
        # can't tolerate this.
        # the server is either not a juno server or is bugged/mentally unstable.
        log2("duplicate UID $$ref{uid}; dropping $$server{name}");
        $server->{conn}->done('UID collision') if exists $server->{conn};
    }

    # nick collision?
    my $used = user::lookup_by_nick($ref->{nick});
    if ($used) {
        log2("nick collision! $$ref{nick}");
        if ($ref->{time} > $used->{time}) {
            # I lose
            $ref->{nick} = $ref->{uid}
        }
        elsif ($ref->{time} < $used->{time}) {
            # you lose
            $used->channel::mine::send_all_user("NICK $$used{uid}") if $used->is_local;
            $used->change_nick($used->{uid});
        }
        else {
            # we both lose
            $ref->{nick} = $ref->{uid};
            $used->channel::mine::send_all_user("NICK $$used{uid}") if $used->is_local;
            $used->change_nick($used->{uid});
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
    my $channel = channel::lookup_by_name($chname);
    my $time    = $args[3];

    # the channel exists, so just join
    if ($channel) {
        return if $channel->has_user($user);

        # take the lower time
        $channel->channel::mine::take_lower_time($time);

    }

    # channel doesn't exist; make a new one
    else {
        $channel = channel->new({
            name   => $chname,
            'time' => $time
        });
    }

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

    # channel doesn't exist?
    if (!$channel) {
        $server->{conn}->done("channel $args[2] doesn't exist");
        return
    }

    # perspective doesn't exist?
    if (!$perspective) {
        $server->{conn}->done("server $args[4] doesn't exist");
        return
    }

    # ignore if time is older
    return if $args[3] > $channel->{time};

    # take the lower time
    $channel->channel::mine::take_lower_time($args[3]);

    my ($user_result, $server_result) = $channel->handle_mode_string($perspective, $source, col(join ' ', @args[5..$#args]), 1, 1);
    return 1 if !$user_result || $user_result =~ m/^(\+|\-)$/;

    # convert it to our view
    $user_result  = $perspective->convert_cmode_string(gv('SERVER'), $user_result);
    my $from      = $source->isa('user') ? $source->full : $source->isa('server') ? $source->{name} : 'MagicalFairyPrincess';
    $channel->channel::mine::send_all(":$from MODE $$channel{name} $user_result");
}

sub part {
    my ($server, $data, @args) = @_;
    my $user    = user::lookup_by_id(col($args[0]));
    my @m       = split /\s+/, $data, 5;
    my $reason  = $args[4] ? col($m[4]) : q();
    my $channel = channel::lookup_by_name($args[2]);

    # channel doesn't exist?
    if (!$channel) {
        $server->{conn}->done("channel $args[2] doesn't exist");
        return
    }

    # take the lower time
    $channel->channel::mine::take_lower_time($args[3]);

    # ?!?!!?!
    if (!$channel->has_user($user)) {
        log2("attempting to remove $$user{nick} from $$channel{name} but that user isn't on that channel");
        return
    }

    # remove the user and tell the local channel users
    $channel->remove($user);
    my $sreason = $reason ? " :$reason" : q();
    $channel->channel::mine::send_all(':'.$user->full." PART $$channel{name}$sreason");
    return 1
}

# add user mode, compact AUM
sub aum {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    foreach my $str (@args[2..$#args]) {
        my ($name, $letter) = split /:/, $str;
        next unless defined $letter; # just in case..
        $serv->add_umode($name, $letter)
    }
    return 1
}

# add channel mode, compact ACM
sub acm {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    foreach my $str (@args[2..$#args]) {
        my ($name, $letter, $type) = split /:/, $str;
        next unless defined $letter;
        $serv->add_cmode($name, $letter, $type)
    }
    return 1
}

# channel user membership, compact CUM
sub cum {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));

    # we cannot assume that this a new channel
    my $ts      = $args[3];
    my $channel = channel::lookup_by_name($args[2]) || channel->new({ name => $args[2], time => $ts});
    my $newtime = $channel->channel::mine::take_lower_time($ts);

    # lazy mode handling.. # FIXME
    if ($newtime == $ts) { # won the time battle
        my $modestr = col(join ' ', @args[5..$#args]);
        $server->handle(":$$serv{sid} CMODE $$channel{name} $$channel{time} $$serv{sid} :$modestr");
    }

    # no users
    return 1 if $args[4] eq '-';

    USER: foreach my $str (split /,/, $args[4]) {
        my ($uid, $modes) = split /!/, $str;
        my $user          = user::lookup_by_id($uid) or next USER;

        # join the new users
        unless ($channel->has_user($user)) {
            $channel->cjoin($user, $channel->{time});
            $channel->channel::mine::send_all(q(:).$user->full." JOIN $$channel{name}");
        }

        next USER unless $modes;      # the mode part is obviously optional..
        next USER if $newtime != $ts; # the time battle was lost

        # lazy mode setting # FIXME
        # but I think it is a clever way of doing it.
        my $final_modestr = $modes.' '.(($uid.' ') x length $modes);
        my ($user_result, $server_result) = $channel->handle_mode_string($serv, $serv, $final_modestr, 1, 1);
        $user_result  = $serv->convert_cmode_string(gv('SERVER'), $user_result);
        $channel->channel::mine::send_all(":$$serv{name} MODE $$channel{name} $user_result");
    }
    return 1
}

sub topic {
    my ($server, $data, @args) = @_;
    my $source  = utils::global_lookup(col($args[0]));
    my $channel = channel::lookup_by_name($args[2]);

    # check that channel exists
    return unless $channel;

    if ($channel->channel::mine::take_lower_time($args[3]) != $args[3]) {
        # bad channel time
        return
    }

    my $topic = col((split /\s+/, $data, 5)[4]);
    $channel->channel::mine::send_all(':'.$source->full." TOPIC $$channel{name} :$topic");

    # set it
    if (length $topic) {
        $channel->{topic} = {
            setby => $source->full,
            time  => time,
            topic => $topic
        };
    }
    else {
        delete $channel->{topic}
    }

    return 1
}

1
