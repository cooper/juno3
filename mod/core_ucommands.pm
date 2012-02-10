# Copyright (c) 2012, Mitchell Cooper
package ext::core_ucommands;
 
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
    },
    REHASH => {
        code   => \&rehash,
        desc   => 'reload the server configuration'
    },
    KILL => {
        code   => \&ukill,
        desc   => 'forcibly remove a user from the server',
        params => 2
    }
);

our $mod = API::Module->new(
    name        => 'core_ucommands',
    version     => '0.3',
    description => 'the core set of user commands',
    requires    => ['user_commands'],
    initialize  => \&init
);
 
sub init {

    # register user commands
    $mod->register_user_command(
        name        => $_,
        description => $ucommands{$_}{desc},
        parameters  => $ucommands{$_}{params} || undef,
        code        => $ucommands{$_}{code}
    ) || return foreach keys %ucommands;

    undef %ucommands;

    return 1
}


# handlers

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

    # ignore stupid nick changes
    if (lceq $user->{nick} => $newnick) {
        return
    }

    # tell ppl
    $user->channel::mine::send_all_user("NICK $newnick");

    # change it
    $user->change_nick($newnick);
    server::mine::fire_command_all(nickchange => $user);
}

sub info {
    my ($NAME, $VERSION) = (gv('NAME'), gv('VERSION'));
    my $user = shift;
    my $info = <<"END";

\2***\2 this is \2$NAME\2 version \2$VERSION\2.\2 ***\2
 
Copyright (c) 2010-12, the juno-ircd developers
 
This program is free software.
You are free to modify and redistribute it under the terms of
the New BSD license.
 
juno3 wouldn't be here if it weren't for the people who have
contributed to the project.
 
\2Developers\2
    Mitchell Cooper, \"cooper\" <mitchell\@notroll.net>
    Kyle Paranoid, \"mac-mini\" <mac-mini\@mac-mini.org>
    Alyx Marie, \"alyx\" <alyx\@malkier.net>
    Brandon Rodriguez, \"Beyond\" <beyond\@mailtrap.org>
    Nick Dalsheimer, \"AstroTurf\" <astronomerturf\@gmail.com>
    Matthew Carey, \"swarley\" <matthew.b.carey\@gmail.com>
    Matthew Barksdale, \"matthew\" <matt\@mattwb65.com>
 
Proudly brought to you by \2\x0302No\x0313Troll\x0304Plz\x0309Net\x0f
https://notroll.net
 
END
    $user->numeric('RPL_INFO', $_) foreach split /\n/, $info;
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
            server::mine::fire_command_all(umode => $user, $result);
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
        #if (!$channel->user_has_basic_status($user)) {
        #    $user->numeric('ERR_CHANOPRIVSNEEDED', $channel->{name});
        #    return
        #}
        # DISABLED, at least for now. we'll see how this will be done later.

        my $modestr = join ' ', @args[2..$#args];
        my ($user_result, $server_result) = $channel->handle_mode_string($user->{server}, $user, $modestr);
        return if (!$user_result || $user_result =~ m/^(\-|\+)$/); # nothing changed

        # tell the channel users
        $channel->channel::mine::send_all(':'.$user->full." MODE $$channel{name} $user_result");
        server::mine::fire_command_all(cmode => $user, $channel, $channel->{time}, $user->{server}->{sid}, $server_result);

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
            server::mine::fire_command($tuser->{location}, privmsgnotice => $command, $user, $tuser->{uid}, $message);
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
            server::mine::fire_command($usr->{location}, privmsgnotice => $command, $user, $channel->{name}, $message);
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
        server::mine::fire_command_all(sjoin => $user, $channel, $time);
        server::mine::fire_command_all(cmode => $user->{server}, $channel, $time, gv('SERVER', 'sid'), $result) if $result;

        # tell servers that this user gets owner
        if ($new) {
            $channel->add_to_list($_, $user) foreach qw/owner op/;
            my $owner = gv('SERVER')->cmode_letter('owner');
            my $op    = gv('SERVER')->cmode_letter('op');
            server::mine::fire_command_all(cmode => $user->{server}, $channel, $time, gv('SERVER', 'sid'), "+$owner$op $$user{uid} $$user{uid}");
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
    server::mine::fire_command_all(oper => $user, @flags);

    # okay, we should have a complete list of flags now.
    log2("$$user{nick}!$$user{ident}\@$$user{host} has opered as $args[1] and now has flags: @flags");

    # this will set ircop as well as send a MODE to the user
    my $result = $user->handle_mode_string('+'.$user->{server}->umode_letter('ircop'), 1);
    if ($result && $result ne '+') {
        server::mine::fire_command_all(umode => $user, $result);
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
        server::mine::fire_command_all(away => $user);
        $user->numeric('RPL_NOWAWAY');
        return 1
    }

    # unsetting
    return unless exists $user->{away};
    $user->unset_away;
    server::mine::fire_command_all(return_away => $user);
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
        server::mine::fire_command_all(part => $user, $channel, $channel->{time}, $reason);
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
        server::mine::fire_command_all(topic => $user, $channel, time, $topic);

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

sub rehash {
    my ($user, $data, @args) = @_;

    # make sure they have rehash flag
    if (!$user->has_flag('rehash')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    if (utils::parse_config('etc/ircd.conf')) {
        $user->server_notice('rehash', 'configuration loaded successfully');
        return 1
    }

    $user->server_notice('rehash', 'there was an error parsing the configuration.');
    return
}

sub ukill {
    my ($user, $data, @args) = @_;

    # make sure they have kill flag
    if (!$user->has_flag('kill')) {
        $user->numeric('ERR_NOPRIVILEGES');
        return
    }

    my $tuser  = user::lookup_by_nick($args[1]);
    my $reason = col((split /\s+/, $data, 3)[2]);

    # no such nick
    if (!$tuser) {
        $user->numeric(ERR_NOSUCHNICK => $args[1]);
        return
    }

    if ($tuser->is_local) {
        $tuser->{conn}->done("Killed: $reason [$$user{nick}]");
        $user->server_notice('kill', "$$tuser{nick} has been killed.");
    }

    return # global kills not yet implemented
}

$mod
