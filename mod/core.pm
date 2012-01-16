# Copyright (c) 2012, Mitchell Cooper
package ext::core;
 
use warnings;
use strict;
 
use utils qw(col log2 lceq lconf match cut_to_limit conf gv);

my %ucommands = (
    PING => {
        params => 1,
        code   => \&ping,
        desc   => 'ping the server'
    },
    USER => {
        code   => \&fake_user,
        desc   => 'fake user command'
    },
    MOTD => {
        code   => \&motd,
        desc   => 'display the message of the day'
    },
    NICK => {
        params => 1,
        code   => \&nick,
        desc   => 'change your nickname'
    },
    PONG => {
        code   => sub { },
        desc   => 'reply to a ping'
    },
    INFO => {
        code   => \&info,
        desc   => 'display ircd license and credits'
    },
    MODE => {
        params => 1,
        code   => \&mode,
        desc   => 'view or change user and channel modes'
    },
    PRIVMSG => {
        params => 2,
        code   => \&privmsgnotice,
        desc   => 'send a message to a user or channel'
    },
    NOTICE => {
        params => 2,
        code   => \&privmsgnotice,
        desc   => 'send a notice to a user or channel'
    },
    MAP => {
        code   => \&cmap,
        desc   => 'view a list of servers connected to the network'
    },
    JOIN => {
        params => 1,
        code   => \&cjoin,
        desc   => 'join a channel'
    },
    NAMES => {
        params => 1,
        code   => \&names,
        desc   => 'view the user list of a channel'
    },
    OPER => {
        params => 2,
        code   => \&oper,
        desc   => 'gain privileges of an IRC operator'

    },
    WHOIS => {
        params => 1,
        code   => \&whois,
        desc   => 'display information on a user'
    },
    ISON => {
        params => 1,
        code   => \&ison,
        desc   => 'check if users are online'
    },
    COMMANDS => {
        code   => \&commands,
        desc   => 'view a list of available commands'
    },
    AWAY => {
        code   => \&away,
        desc   => 'mark yourself as away or return from being away'
    },
    QUIT => {
        code   => \&quit,
        desc   => 'disconnect from the server'
    },
    PART => {
        params => 1,
        code   => \&part,
        desc   => 'leave a channel'
    },
    CONNECT => {
        params => 1,
        code   => \&sconnect,
        desc   => 'connect to a server'
    },
    WHO => {
        params => 1,
        code   => \&who,
        desc   => 'familiarize your client with users matching a pattern'
    },
    TOPIC => {
        params => 1,
        code   => \&topic,
        desc   => 'view or set the topic of a channel'
    },
    IRCD => {
        code   => \&ircd,
        desc   => 'view ircd information'
    },
    LUSERS => {
        code   => \&lusers,
        desc   => 'view connection count statistics'
    },
    MODLOAD => {
        code   => \&modload,
        desc   => 'load an IRCd extension',
        params => 1
    },
    MODUNLOAD => {
        code   => \&modunload,
        desc   => 'unload an IRCd extension',
        params => 1
    },
    MODRELOAD => {
        code   => \&modreload,
        desc   => 'reload an IRCd extension',
        params => 1
    },
    VERIFY => {
        code   => \&verify,
        desc   => 'verify doing something which could be harmful'
    }
);

my %scommands = (
    SID => {
        params  => 6,
        forward => 1,
        code    => \&s_sid
    },
    UID => {
        params  => 9,
        forward => 1,
        code    => \&s_uid
    },
    QUIT => {
        params  => 1,
        forward => 1,
        code    => \&s_quit
    },
    NICK => {
        params  => 1,
        forward => 1,
        code    => \&s_nick
    },
    BURST => {
        params  => 0,
        forward => 1,
        code    => \&s_burst
    },
    ENDBURST => {
        params  => 0,
        forward => 1,
        code    => \&s_endburst
    },
    ADDUMODE  => {
        params  => 2,
        forward => 1,
        code    => \&s_addumode
    },
    UMODE => {
        params  => 1,
        forward => 1,
        code    => \&s_umode
    },
    PRIVMSG => {
        params  => 2,
        forward => 0, # we have to figure ourself
        code    => \&s_privmsgnotice
    },
    NOTICE => {
        params  => 2,
        forward => 0, # we have to figure ourself
        code    => \&s_privmsgnotice
    },
    JOIN => {
        params  => 2,
        forward => 1,
        code    => \&s_sjoin
    },
    OPER => {
        params  => 1,
        forward => 1,
        code    => \&s_oper
    },
    AWAY => {
        params  => 1,
        forward => 1,
        code    => \&s_away
    },
    RETURN => {
        params  => 0,
        forward => 1,
        code    => \&s_return_away
    },
    ADDCMODE => {
        params  => 3,
        forward => 1,
        code    => \&s_addcmode
    },
    CMODE => {
        params  => 4,
        forward => 1,
        code    => \&s_cmode
    },
    PART => {
        params  => 1,
        forward => 1,
        code    => \&s_part
    },
    TOPIC => {
        params  => 4,
        forward => 1,
        code    => \&s_topic
    },
    TOPICBURST => {
        params  => 4,
        forward => 1,
        code    => \&s_topicburst
    },

    # compact

    AUM => {
        params  => 1,
        forward => 1,
        code    => \&s_aum
    },
    ACM => {
        params  => 1,
        forward => 1,
        code    => \&s_acm
    },
    CUM => {
        params  => 4,
        forward => 1,
        code    => \&s_cum
    }
);

my %umodes = (
    ircop => \&umode_ircop
);

my %cmodes = (
    ban => \&cmode_ban
);

our $mod = API::Module->new(
    name        => 'core',
    version     => '0.1',
    description => 'the core set of commands and modes',
    requires    => ['user_commands', 'user_modes', 'channel_modes', 'server_commands'],
    initialize  => \&init
);
 
sub init {

    # register user mode blocks
    $mod->register_user_mode_block(
        name => $_,
        code => $umodes{$_}
    ) || return foreach keys %umodes;

    # register channel mode blocks
    $mod->register_channel_mode_block(
        name => $_,
        code => $cmodes{$_}
    ) || return foreach keys %cmodes;

    # register user commands
    $mod->register_user_command(
        name        => $_,
        description => $ucommands{$_}{desc},
        parameters  => $ucommands{$_}{params} || undef,
        code        => $ucommands{$_}{code}
    ) || return foreach keys %ucommands;

    # register server commands
    $mod->register_server_command(
        name        => $_,
        parameters  => $scommands{$_}{params} || undef,
        code        => $scommands{$_}{code}
    ) || return foreach keys %scommands;

    # register status channel modes
    register_statuses() or return;

    undef %scommands;
    undef %ucommands;
    undef %cmodes;
    undef %umodes;

    return 1
}

##############
# USER MODES #
##############

sub umode_ircop {
    my ($user, $state) = @_;
    return if $state; # /never/ allow setting ircop

    # but always allow them to unset it
    log2("removing all flags from $$user{nick}");
    $user->{flags} = [];
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

###################
# SERVER COMMANDS #
###################

sub s_sid {
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

sub s_uid {
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
        #if ($ref->{time} > $used->{time}) {
        #    # I lose
        #    $ref->{nick} = $ref->{uid}
        #}
        #elsif ($ref->{time} < $used->{time}) {
        #    # you lose
        #    $used->channel::mine::send_all_user("NICK $$used{uid}") if $used->is_local;
        #    $used->change_nick($used->{uid});
        #}
        #else {
            # we both lose
            $ref->{nick} = $ref->{uid};
            $used->channel::mine::send_all_user("NICK $$used{uid}");
            $used->change_nick($used->{uid});
        #}
    }

    # create a new user
    my $user = user->new($ref);

    # set modes
    $user->handle_mode_string($ref->{modes}, 1);

    return 1

}

sub s_quit {
    my ($server, $data, @args) = @_;

    # find the server or user
    my $source = utils::global_lookup(col($args[0]));

    # delete the server or user
    $source->quit(col(join ' ', @args[2..$#args]));
}

sub s_nick {
    # handle a nickchange
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));

    # tell ppl
    $user->channel::mine::send_all_user("NICK $args[2]");

    $user->change_nick($args[2])
}

sub s_burst {
    my $server = shift;
    $server->{is_burst} = 1;
    log2("$$server{name} is bursting information")
}

sub s_endburst {
    my $server = shift;
    delete $server->{is_burst};
    $server->{sent_burst} = 1;
    log2("end of burst from $$server{name}")
}

sub s_addumode {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    $serv->add_umode($args[2], $args[3]);
}

sub s_umode {
    # why would umodes need time stamps?
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->handle_mode_string($args[2], 1);
}

sub s_privmsgnotice {
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
sub s_sjoin {
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
sub s_oper {
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->add_flags(@args[2..$#args]);
}

sub s_away {
    my ($server, $data, @args) = @_;
    my $user   = user::lookup_by_id(col($args[0]));
    my $reason = col((split /\s+/, $data, 3)[2]);
    $user->set_away($reason);
}

sub s_return_away {
    my ($server, $data, @args) = @_;
    my $user = user::lookup_by_id(col($args[0]));
    $user->return_away();
}

# add a channel mode
sub s_addcmode {
    my ($server, $data, @args) = @_;
    my $serv = server::lookup_by_id(col($args[0]));
    $serv->add_cmode($args[2], $args[3], $args[4]);
}

# set a mode on a channel
sub s_cmode {
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

sub s_part {
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
sub s_aum {
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
sub s_acm {
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
sub s_cum {
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

sub s_topic {
    # :source TOPIC channel ts time :topic
    my ($server, $data, @args) = @_;
    my $source  = utils::global_lookup(col($args[0]));
    my $channel = channel::lookup_by_name($args[2]);

    # check that channel exists
    return unless $channel;

    if ($channel->channel::mine::take_lower_time($args[3]) != $args[3]) {
        # bad channel time
        return
    }

    my $topic = col((split /\s+/, $data, 6)[5]);
    $channel->channel::mine::send_all(':'.$source->full." TOPIC $$channel{name} :$topic");

    # set it
    if (length $topic) {
        $channel->{topic} = {
            setby => $source->full,
            time  => $args[4],
            topic => $topic
        };
    }
    else {
        delete $channel->{topic}
    }

    return 1
}

sub s_topicburst {
    # :sid TOPICBURST channel time setby time :topic
    my ($server, $data, @args) = @_;
    my $source  = utils::global_lookup(col($args[0]));
    my $channel = channel::lookup_by_name($args[2]);

    # check that channel exists
    return unless $channel;

    if ($channel->channel::mine::take_lower_time($args[3]) != $args[3]) {
        # bad channel time
        return
    }

    my $topic = col((split /\s+/, $data, 7)[6]);
    $channel->channel::mine::send_all(':'.$source->full." TOPIC $$channel{name} :$topic");

    # set it
    if (length $topic) {
        $channel->{topic} = {
            setby => $args[4],
            time  => $args[5],
            topic => $topic
        };
    }
    else {
        delete $channel->{topic}
    }

    return 1
}

#################
# USER COMMANDS #
#################

sub ping {
    my ($user, $data, @s) = @_;
    $user->sendserv('PONG '.gv('SERVER', 'name').' :'.col($s[1]))
}

sub fake_user {
    my $user = shift;
    $user->numeric('ERR_ALREADYREGISTRED');
}

sub motd {
    # TODO <server> parameter
    my $user = shift;
    if (!defined gv('MOTD')) {
        $user->numeric('ERR_NOMOTD');
        return
    }
    $user->numeric('RPL_MOTDSTART', gv('SERVER', 'name'));
    foreach my $line (@{gv('MOTD')}) {
        $user->numeric('RPL_MOTD', $line)
    }
    $user->numeric('RPL_ENDOFMOTD');
    return 1
}

# change nickname
sub nick {
    my ($user, $data, @args) = @_;
    my $newnick = col($args[1]);

    if ($newnick eq '0') {
        $newnick = $user->{uid}
    }
    else {
        # ignore stupid nick changes
        if (lceq $user->{nick} => $newnick) {
            return
        }

        # check for valid nick
        if (!utils::validnick($newnick)) {
            $user->numeric('ERR_ERRONEUSNICKNAME', $newnick);
            return
        }

        # check for existing nick
        if (user::lookup_by_nick($newnick)) {
            $user->numeric('ERR_NICKNAMEINUSE', $newnick);
            return
        }
    }

    # tell ppl
    $user->channel::mine::send_all_user("NICK $newnick");

    # change it
    $user->change_nick($newnick);

    server::outgoing::nickchange_all($user);
}

sub info {
    my $user = shift;
    my @info = (
        " ",
        "\2***\2 this is \2".gv('NAME')."\2 version \2".gv('VERSION')."\2.\2 ***\2",
        " "                                                             ,
        "Copyright (c) 2010-12, the juno-ircd developers"                  ,
        " "                                                             ,
        "This program is free software."                                ,
        "You are free to modify and redistribute it under the terms of" ,
        "the New BSD license."                                          ,
        " "                                                             ,
        "juno3 wouldn't be here if it weren't for the people who have"  ,
        "contributed to the project."                                   ,
        " "                                                             ,
        "\2Developers\2"                                                ,
        "    Mitchell Cooper, \"cooper\" <mitchell\@notroll.net>"       ,
        "    Kyle Paranoid, \"mac-mini\" <mac-mini\@mac-mini.org>"      ,
        "    Alyx Marie, \"alyx\" <alyx\@malkier.net>"                  ,
        "    Brandon Rodriguez, \"Beyond\" <beyond\@mailtrap.org>"      ,
        "    Nick Dalsheimer, \"AstroTurf\" <astronomerturf\@gmail.com>",
        "    Matthew Carey, \"swarley\" <matthew.b.carey\@gmail.com>"   ,
        "    Matthew Barksdale, \"matthew\" <matt\@mattwb65.com>"       ,
        " "                                                             ,
        "Proudly brought to you by \2\x0302No\x0313Troll\x0304Plz\x0309Net\x0f",
        "https://notroll.net"                                           ,
        " "
    );
    $user->numeric('RPL_INFO', $_) foreach @info;
    $user->numeric('RPL_ENDOFINFO');
    return 1
}

sub mode {
    my ($user, $data, @args) = @_;

    # is it the user himself?
    if (lceq $user->{nick} => $args[1]) {

        # mode change
        if (defined $args[2]) {
            my $result = $user->handle_mode_string($args[2]);
            return if !$result || $result =~ m/^(\-|\+)$/;
            $user->sendfrom($user->{nick}, "MODE $$user{nick} :$result");
            server::outgoing::umode_all($user, $result);
            return 1
        }

        # mode view
        else {
            $user->numeric('RPL_UMODEIS', $user->mode_string);
            return 1
        }
    }

    # is it a channel, then?
    if (my $channel = channel::lookup_by_name($args[1])) {

        # viewing
        if (!defined $args[2]) {
            $channel->channel::mine::modes($user);
            return 1
        }

        # setting

        # does he have op?
        if (!$channel->user_has_basic_status($user)) {
            $user->numeric('ERR_CHANOPRIVSNEEDED', $channel->{name});
            return
        }

        my $modestr = join ' ', @args[2..$#args];
        my ($user_result, $server_result) = $channel->handle_mode_string($user->{server}, $user, $modestr);
        return if (!$user_result || $user_result =~ m/^(\-|\+)$/); # nothing changed

        # tell the channel users
        $channel->channel::mine::send_all(':'.$user->full." MODE $$channel{name} $user_result");
        $user->server::outgoing::cmode_all($channel, $channel->{time}, $user->{server}->{sid}, $server_result);

        return 1
    }

    # hmm.. maybe it's another user
    if (user::lookup_by_nick($args[1])) {
        $user->numeric('ERR_USERSDONTMATCH');
        return
    }

    # no such nick/channel
    $user->numeric('ERR_NOSUCHNICK', $args[1]);
    return
}

sub privmsgnotice {
    my ($user, $data, @args) = @_;

    # we can't  use @args because it splits by whitespace
    $data       =~ s/^:(.+)\s//;
    my @m       = split ' ', $data, 3;
    my $message = col($m[2]);
    my $command = uc $m[0];

    # no text to send
    if ($message eq '') {
        $user->numeric('ERR_NOTEXTTOSEND');
        return
    }

    # is it a user?
    my $tuser = user::lookup_by_nick($args[1]);
    if ($tuser) {

        # TODO here check for user modes preventing
        # the user from sending the message

        # tell them of away if set
        if ($command eq 'PRIVMSG' && exists $user->{away}) {
            $user->numeric('RPL_AWAY', $tuser->{nick}, $tuser->{away});
        }

        # if it's a local user, send it to them
        if ($tuser->is_local) {
            $tuser->sendfrom($user->full, "$command $$tuser{nick} :$message");
        }

        # send it to the server holding this user
        else {
            $tuser->{location}->server::outgoing::privmsgnotice($command, $user, $tuser->{uid}, $message);
        }
        return 1
    }

    # must be a channel
    my $channel = channel::lookup_by_name($args[1]);
    if ($channel) {

        # no external messages?
        if ($channel->is_mode('no_ext') && !$channel->has_user($user)) {
            $user->numeric('ERR_CANNOTSENDTOCHAN', $channel->{name}, 'no external messages');
            return
        }

        # moderation and no voice?
        if ($channel->is_mode('moderated')   &&
          !$channel->user_is($user, 'voice') &&
          !$channel->user_has_basic_status($user)) {
            $user->numeric('ERR_CANNOTSENDTOCHAN', $channel->{name}, 'channel is moderated');
            return
        }
                

        # tell local users
        $channel->channel::mine::send_all(':'.$user->full." $command $$channel{name} :$message", $user);

        # then tell local servers
        my %sent;
        foreach my $usr (values %user::user) {
            next if $usr->is_local;
            next if $sent{$usr->{location}};
            $sent{$usr->{location}} = 1;
            $usr->{location}->server::outgoing::privmsgnotice($command, $user, $channel->{name}, $message);
        }

        return 1
    }

    # no such nick/channel
    $user->numeric('ERR_NOSUCHNICK', $args[1]);
    return
}

sub cmap {
    # TODO this will be much prettier later!
    my $user  = shift;
    foreach my $server (values %server::server) {
        $user->numeric('RPL_MAP', '    '.$server->{name}.':'.$server->{sid})
    }
    $user->numeric('RPL_MAPEND');
}

sub cjoin {
    my ($user, $data, @args) = @_;
    foreach my $chname (split ',', $args[1]) {
        my $new = 0;

        # make sure it's a valid name
        if (!utils::validchan($chname)) {
            $user->numeric('ERR_NOSUCHCHANNEL', $chname);
            next
        }

        # if the channel exists, just join
        my $channel = channel::lookup_by_name($chname);
        my $time    = time;
        my $result;

        # otherwise create a new one
        if (!$channel) {
            $channel = channel->new({
                name   => $chname,
                'time' => $time
            });
            $new     = 1;
            $result  = $channel->handle_mode_string($user->{server}, $user->{server}, conf('channels', 'automodes'), 1);
        }
        return if $channel->has_user($user);

        # check for ban
        if ($channel->list_matches('ban', $user->fullcloak) || $channel->list_matches('ban', $user->full)) {
            $user->numeric('ERR_BANNEDFROMCHAN', $channel->{name});
            return
        }

        # tell servers that the user joined and the automatic modes were set
        server::outgoing::sjoin_all($user, $channel, $time);
        server::outgoing::cmode_all($user->{server}, $channel, $time, gv('SERVER', 'sid'), $result) if $result;

        # tell servers that this user gets owner
        if ($new) {
            $channel->add_to_list($_, $user) foreach qw/owner op/;
            my $owner = gv('SERVER')->cmode_letter('owner');
            my $op    = gv('SERVER')->cmode_letter('op');
            server::outgoing::cmode_all($user->{server}, $channel, $time, gv('SERVER', 'sid'), "+$owner$op $$user{uid} $$user{uid}");
        }

        $channel->channel::mine::cjoin($user, $time)
    }
}

sub names {
    my ($user, $data, @args) = @_;
    foreach my $chname (split ',', $args[1]) {
        # nonexistent channels return no error,
        # and RPL_ENDOFNAMES is sent no matter what
        my $channel = channel::lookup_by_name($chname);
        $channel->channel::mine::names($user) if $channel;
        $user->numeric('RPL_ENDOFNAMES', $channel ? $channel->{name} : $chname);
    }
}

sub oper {
    my ($user, $data, @args) = @_;
    my $password = lconf('oper', $args[1], 'password');
    my $supplied = $args[2];

    # no password?!
    if (not defined $password) {
        $user->numeric('ERR_NOOPERHOST');
        return
    }

    # if they have specific addresses specified, make sure they match

    if (defined( my $addr = lconf('oper', $args[1], 'host') )) {
        my $win = 0;

        # a reference of several addresses
        if (ref $addr eq 'ARRAY') {
            match: foreach my $host (@$addr) {
                if (match($user->full, $host) || match("$$user{nick}!$$user{ident}\@$$user{ip}", $host)) {
                    $win = 1;
                    last match
                }
            }
        }

        # must just be a string of 1 address
        else {
            if (match($user->{host}, $addr) || match($user->{ip}, $addr)) {
                $win = 1
            }
        }

        # nothing matched :(
        if (!$win) {
            $user->numeric('ERR_NOOPERHOST');
            return
        }
    }

    my $crypt = lconf('oper', $args[1], 'encryption');

    # so now let's check if the password is right
    $supplied = utils::crypt($supplied, $crypt);

    # incorrect
    if ($supplied ne $password) {
        $user->numeric('ERR_NOOPERHOST');
        return
    }

    # or keep going!
    # let's find all of their oper flags now

    my @flags;

    # flags in their oper block
    if (defined ( my $flagref = lconf('oper', $args[1], 'flags') )) {
        if (ref $flagref ne 'ARRAY') {
            log2("'flags' specified for oper block $args[1], but it is not an array reference.");
        }
        else {
            push @flags, @$flagref
        }
    }

    # flags in their oper class block
    my $add_class = sub {
        my $add_class = shift;
        my $operclass = shift;

        # if it has flags, add them
        if (defined ( my $flagref = lconf('operclass', $operclass, 'flags') )) {
            if (ref $flagref ne 'ARRAY') {
                log2("'flags' specified for oper class block $operclass, but it is not an array reference.");
            }
            else {
                push @flags, @$flagref
            }
        }

        # add parent too
        if (defined ( my $parent = lconf('operclass', $operclass, 'extends') )) {
            $add_class->($add_class, $parent);
        }
    };

    if (defined ( my $operclass = lconf('oper', $args[1], 'class') )) {
        $add_class->($add_class, $operclass);
    }

    my %h = map { $_ => 1 } @flags;
    @flags = keys %h; # should remove duplicates
    $user->add_flags(@flags);
    server::outgoing::oper_all($user, @flags);

    # okay, we should have a complete list of flags now.
    log2("$$user{nick}!$$user{ident}\@$$user{host} has opered as $args[1] and now has flags: @flags");

    # this will set ircop as well as send a MODE to the user
    my $result = $user->handle_mode_string('+'.$user->{server}->umode_letter('ircop'), 1);
    if ($result && $result ne '+') {
        server::outgoing::umode_all($user, $result);
        $user->sendfrom($user->{nick}, "MODE $$user{nick} :$result");
    }

    $user->numeric('RPL_YOUREOPER', join(' ', @{$user->{flags}}));
    return 1
}

sub whois {

    my ($user, $data, @args) = @_;

    # this is the way inspircd does it so I can too
    my $query = $args[2] ? $args[2] : $args[1];
    my $quser = user::lookup_by_nick($query);

    # exists?
    if (!$quser) {
        $user->numeric('ERR_NOSUCHNICK', $query);
        return
    }

    # nick, ident, host
    $user->numeric('RPL_WHOISUSER', $quser->{nick}, $quser->{ident}, $quser->{host}, $quser->{real});

    # channels
    my @channels = map { $_->{name} } grep { $_->has_user($quser) } values %channel::channels;
    $user->numeric('RPL_WHOISCHANNELS', $quser->{nick}, join(' ', @channels)) if @channels;

    # server 
    $user->numeric('RPL_WHOISSERVER', $quser->{nick}, $quser->{server}->{name}, $quser->{server}->{desc});

    # IRC operator
    $user->numeric('RPL_WHOISOPERATOR', $quser->{nick}) if $quser->is_mode('ircop');

    # is away
    $user->numeric('RPL_AWAY', $quser->{nick}, $quser->{away}) if exists $quser->{away};

    # using modes
    my $modes = $quser->mode_string;
    $user->numeric('RPL_WHOISMODES', $quser->{nick}, $modes) if $modes && $modes ne '+';

    # connecting from
    $user->numeric('RPL_WHOISHOST', $quser->{nick}, $quser->{host}, $quser->{ip});

    # TODO 137 idle

    $user->numeric('RPL_ENDOFWHOIS', $quser->{nick});
    return 1
}

sub ison {
    my ($user, $data, @args) = @_;
    my @found;

    # for each nick, lookup and add if exists
    foreach my $nick (@args[1..$#args]) {
        my $user = user::lookup_by_nick(col($nick));
        push @found, $user->{nick} if $user
    }

    $user->numeric('RPL_ISON', join('', @found));
}

sub commands {
    my $user = shift;

    # get the width
    my $i = 0;
    foreach my $command (keys %user::mine::commands) {
        $i = length $command if length $command > $i
    }

    $i++;
    $user->server_notice('*** List of available commands');

    # send a notice for each command
    foreach my $command (keys %user::mine::commands) {
        foreach my $source (keys %{$user::mine::commands{$command}}) {
            $user->server_notice(sprintf "%-${i}s [\2%s\2] %-${i}s", $command,
                $source, $user::mine::commands{$command}{$source}{desc})
        }
    }

    $user->server_notice('*** End of command list');

}

sub away {
    my ($user, $data, @args) = @_;

    # setting away
    if (defined $args[1]) {
        my $reason = cut_to_limit('away', col((split /\s+/, $data, 2)[1]));
        $user->set_away($reason);
        server::outgoing::away_all($user);
        $user->numeric('RPL_NOWAWAY');
        return 1
    }

    # unsetting
    $user->unset_away;
    server::outgoing::return_away_all($user);
    $user->numeric('RPL_UNAWAY');
}

sub quit {
    my ($user, $data, @args) = @_;
    my $reason = 'leaving';

    # get the reason if they specified one
    if (defined $args[1]) {
        $reason = col((split /\s+/,  $data, 2)[1])
    }

    $user->{conn}->done("~$reason");
}

sub part {
    my ($user, $data, @args) = @_;
    my @m = split /\s+/, $data, 3;
    my $reason = $args[2] ? col($m[2]) : q();

    foreach my $chname (split ',', $args[1]) {
        my $channel = channel::lookup_by_name($chname);

        # channel doesn't exist
        if (!$channel) {
            $user->numeric('ERR_NOSUCHCHANNEL', $chname);
            return
        }

        # user isn't on channel
        if (!$channel->has_user($user)) {
            $user->numeric('ERR_NOTONCHANNEL', $channel->{name});
            return
        }

        # remove the user and tell the other channel's users and servers
        my $ureason = $reason ? " :$reason" : q();
        $channel->channel::mine::send_all(':'.$user->full." PART $$channel{name}$ureason");
        $user->server::outgoing::part_all($channel, $channel->{time}, $reason);
        $channel->remove($user);

    }
}

sub sconnect {
    my ($user, $data, @args) = @_;
    my $server = $args[1];

    # make sure they have connect flag
    if (!$user->has_flag('connect')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    # make sure the server exists
    if (!exists $utils::conf{connect}{$server}) {
        $user->server_notice('CONNECT', 'no such server '.$server);
        return
    }

    # make sure it's not already connected
    if (server::lookup_by_name($server)) {
        $user->server_notice('CONNECT', "$server is already connected.");
        return
    }

    if (!server::linkage::connect_server($server)) {
        $user->server_notice('CONNECT', 'couldn\'t connect to '.$server);
    }
}

#########################################################################
#                           WHO query :(                                #
#-----------------------------------------------------------------------#
#                                                                       #
# I'll try to do what rfc2812 says this time.                           #
#                                                                       #
# The WHO command is used by a client to generate a query which returns #
# a list of information which 'matches' the <mask> parameter given by   #
# the client.  In the absence of the <mask> parameter, all visible      #
# (users who aren't invisible (user mode +i) and who don't have a       #
# common channel with the requesting client) are listed.  The same      #
# result can be achieved by using a <mask> of "0" or any wildcard which #
# will end up matching every visible user.                              #
#                                                                       #
# by the looks of it, we can match a username, nickname, real name,     #
# host, or server name.                                                 #
#########################################################################

sub who {
    my ($user, $data, @args) = @_;
    my $query                = $args[1];
    my $match_pattern        = '*';
    my %matches;

    # match all, like the above note says
    if ($query eq '0') {
        foreach my $quser (values %user::user) {
            $matches{$quser->{uid}} = $quser
        }
        # I used UIDs so there are no duplicates
    }

    # match an exact channel name
    elsif (my $channel = channel::lookup_by_name($query)) {
        $match_pattern = $channel->{name};
        foreach my $quser (@{$channel->{users}}) {
            $matches{$quser->{uid}} = $quser;
            $quser->{who_flags}     = $channel->channel::mine::prefix($quser);
        }
    }

    # match a pattern
    else {
        foreach my $quser (values %user::user) {
            foreach my $pattern ($quser->{nick}, $quser->{ident}, $quser->{host},
              $quser->{real}, $quser->{server}->{name}) {
                $matches{$quser->{uid}} = $quser if match($pattern, $query);
            }
        }
        # this doesn't have to match anyone
    }

    # weed out invisibles
    foreach my $uid (keys %matches) {
        my $quser     = $matches{$uid};
        my $who_flags = delete $quser->{who_flags} || '';

        # weed out invisibles
        next if ($quser->is_mode('invisible') && !channel::in_common($user, $quser) && !$user->has_flag('see_invisible'));

        # rfc2812:
        # If the "o" parameter is passed only operators are returned according
        # to the <mask> supplied.
        next if (defined $args[2] && $args[2] =~ m/o/ && !$quser->is_mode('ircop'));

        # found a match
        $who_flags .= (defined $quser->{away} ? 'G' : 'H') . ($quser->is_mode('ircop') ? '*' : q||);
        $user->numeric('RPL_WHOREPLY', $match_pattern, $quser->{ident}, $quser->{host}, $quser->{server}->{name}, $quser->{nick}, $who_flags, $quser->{real});
    }

    $user->numeric('RPL_ENDOFWHO', $query);
    return 1
}

sub topic {
    my ($user, $data, @args) = @_;
    $args[1] =~ s/,(.*)//; # XXX: comma separated list won't work here!
    my $channel = channel::lookup_by_name($args[1]);

    # existent channel?
    if (!$channel) {
        $user->numeric(ERR_NOSUCHCHANNEL => $args[1]);
        return
    }

    # setting topic
    if (defined $args[2]) {
        my $can = (!$channel->is_mode('protect_topic')) ? 1 : $channel->user_has_basic_status($user) ? 1 : 0;

        # not permitted
        if (!$can) {
            $user->numeric(ERR_CHANOPRIVSNEEDED => $channel->{name});
            return
        }

        my $topic = cut_to_limit('topic', col((split /\s+/, $data, 3)[2]));
        $channel->channel::mine::send_all(':'.$user->full." TOPIC $$channel{name} :$topic");
        server::outgoing::topic_all($user, $channel, time, $topic);

        # set it
        if (length $topic) {
            $channel->{topic} = {
                setby => $user->full,
                time  => time,
                topic => $topic
            };
        }
        else {
            delete $channel->{topic}
        }

    }

    # viewing topic
    else {

        # topic set
        if (exists $channel->{topic}) {
            $user->numeric(RPL_TOPIC        => $channel->{name}, $channel->{topic}->{topic});
            $user->numeric(RPL_TOPICWHOTIME => $channel->{name}, $channel->{topic}->{setby}, $channel->{topic}->{time});
        }

        # no topic set
        else {
            $user->numeric(RPL_NOTOPIC => $channel->{name});
            return
        }
    }

    return 1
}

sub ircd {
    my $user = shift;
    $user->server_notice('*** ircd information');
    $user->server_notice('    version');
    $user->server_notice('        '.gv('NAME').' version '.gv('VERSION').' proto '.gv('PROTO'));
    $user->server_notice('    startup time');
    $user->server_notice('        '.POSIX::strftime('%a %b %d %Y at %H:%M:%S %Z', localtime gv('START')));
    $user->server_notice('    loaded perl modules');
    $user->server_notice("        $_") foreach keys %INC;
    $user->server_notice('    for command list see COMMANDS');
    $user->server_notice('    for license see INFO');
    $user->server_notice('*** End of ircd information');

}

sub lusers {
    my ($user, $data, @args) = @_;

    # get server count
    my $servers   = scalar keys %server::server;
    my $l_servers = scalar grep { $_->is_local } values %server::server;

    # get x users, x invisible, and total global
    my ($g_not_invisible, $g_invisible) = (0, 0);
    foreach my $user (values %user::user) {
        $g_invisible++, next if $user->is_mode('invisible');
        $g_not_invisible++
    }
    my $g_users = $g_not_invisible + $g_invisible;

    # get local users
    my $l_users  = scalar grep { $_->is_local } values %user::user;

    # get connection count and max connection count
    my $conn     = gv('connection_count');
    my $conn_max = gv('max_connection_count');

    # get oper count and channel count
    my $opers = scalar grep { $_->is_mode('ircop') } values %user::user;
    my $chans = scalar keys %channel::channel;

    # get max global and max local
    my $m_global = gv('max_global_user_count');
    my $m_local  = gv('max_local_user_count');

    # send numerics
    $user->numeric(RPL_LUSERCLIENT   => $g_not_invisible, $g_invisible, $servers);
    $user->numeric(RPL_LUSEROP       => $opers);
    $user->numeric(RPL_LUSERCHANNELS => $chans);
    $user->numeric(RPL_LUSERME       => $l_users, $l_servers);
    $user->numeric(RPL_LOCALUSERS    => $l_users, $m_local, $l_users, $m_local);
    $user->numeric(RPL_GLOBALUSERS   => $g_users, $m_global, $g_users, $m_global);
    $user->numeric(RPL_STATSCONN     => $conn_max, $m_local, $conn);
}

sub modload {
    my ($user, $data, @args) = @_;

    # must have modload flag
    if (!$user->has_flag('modload')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    $user->server_notice("Loading module \2$args[1]\2.");

    my $result = API::load_module($args[1], "$args[1].pm");

    if (!$result) {
        $user->server_notice('Module failed to load. See server log for information.');
        return
    }

    # success
    else {
        $user->server_notice('Module loaded successfully.');
        return 1
    }
}

sub modunload {
    my ($user, $data, @args) = @_;

    # must have modunload flag
    if (!$user->has_flag('modunload')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    if (lc $args[1] eq 'core' && !$args[2]) {
        $user->server_notice('I REALLY DOUBT YOU WANT TO DO THAT.');
        $user->server_notice('If you do, use the VERIFY command.');
        $user->{cmd_verify} = sub { $user->handle("$args[0] $args[1] 1") };
        return
    }

    $user->server_notice("Unloading module \2$args[1]\2.");

    my $result = API::unload_module($args[1], "$args[1].pm");

    if (!$result) {
        $user->server_notice('Module failed to unload. See server log for information.');
        return
    }

    # success
    else {
        $user->server_notice('Module unloaded successfully.');
        return 1
    }
}

sub modreload {
    my ($user, $data, @args) = @_;

    # must have mod(un)load flags
    if (!$user->has_flag('modunload') || !$user->has_flag('modload')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    $user->server_notice("Reloading module \2$args[1]\2.");

    # UNLOAD

    my $result = API::unload_module($args[1], "$args[1].pm");

    if (!$result) {
        $user->server_notice('Module failed to unload. See server log for information.');
        return
    }

    # success
    else {
        $user->server_notice('Module unloaded successfully.');
    }

    # LOAD

    $result = API::load_module($args[1], "$args[1].pm");

    if (!$result) {
        $user->server_notice('Module failed to load. See server log for information.');
        return
    }

    # success
    else {
        $user->server_notice('Module loaded successfully.');
        return 1
    }
}

sub verify {
    my ($user, $data, @args) = @_;
    if ($user->{cmd_verify} && ref $user->{cmd_verify} eq 'CODE') {
        $user->server_notice('Okay, if you say so...');
        $user->{cmd_verify}->(@args);
        delete $user->{cmd_verify};
    }

    # nothing
    else {
        $user->server_notice('Sorry, nothing to verify.');
    }
}

$mod
