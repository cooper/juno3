#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::handlers;

use warnings;
use strict;
use feature 'switch';

use utils qw[col log2 lceq lconf match cut_to_limit conf];

my %commands = (
    PING => {
        params => 1,
        code   => \&ping,
        desc   => 'ping the server'
    },
    USER => {
        params => 0,
        code   => \&fake_user,
        desc   => 'fake user command'
    },
    MOTD => {
        params => 0,
        code   => \&motd,
        desc   => 'display the message of the day'
    },
    NICK => {
        params => 1,
        code   => \&nick,
        desc   => 'change your nickname'
    },
    PONG => {
        params => 0,
        code   => sub { },
        desc   => 'reply to a ping'
    },
    INFO => {
        params => 0,
        code   => \&info,
        desc   => 'display IRCd information'
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
        params => 0,
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
        params => 0,
        code   => \&commands,
        desc   => 'view a list of available commands'
    },
    AWAY => {
        params => 0,
        code   => \&away,
        desc   => 'mark yourself as away or return from being away'
    },
    QUIT => {
        params => 0,
        code   => \&quit,
        desc   => 'disconnect from network'
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
    }
);

log2("registering core user handlers");
user::mine::register_handler('core', $_, $commands{$_}{params}, $commands{$_}{code}, $commands{$_}{desc}) foreach keys %commands;
log2("end of core handlers");

sub ping {
    my ($user, $data, @s) = @_;
    $user->sendserv("PONG $utils::GV{servername} :".col($s[1]))
}

sub fake_user {
    my $user = shift;
    $user->numeric('ERR_ALREADYREGISTRED');
}

sub motd {
    # TODO <server> parameter
    my $user = shift;
    if (!defined $utils::GV{motd}) {
        $user->numeric('ERR_NOMOTD');
        return
    }
    $user->numeric('RPL_MOTDSTART', $utils::GV{servername});
    foreach my $line (@{$utils::GV{motd}}) {
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
        "",
        "\2***\2 this is \2$main::NAME\2 version \2$main::VERSION\2.\2 ***\2",
        "",
        "Copyright (c) 2011, Mitchell Cooper",
        "",
        "This program is free software.",
        "You are free to modify and redistribute it under the",
        "terms of the New BSD license.",
        "",
        "\2Developers\2",
        "    Mitchell Cooper, \"cooper\" <cooper\@notroll.net>",
        "",
        "Proudly brought to you by \2\x0302No\x0313Troll\x0304Plz\x0309Net\x0f",
        ""
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

        # tell servers that the user joined and the automatic modes were set
        server::outgoing::sjoin_all($user, $channel, $time);
        server::outgoing::cmode_all($user->{server}, $channel, $time, $utils::GV{server}{sid}, $result) if $result;

        # tell servers that this user gets owner
        if ($new) {
            $channel->add_to_list($_, $user) foreach qw/owner op/;
            my $owner = $utils::GV{server}->cmode_letter('owner');
            my $op    = $utils::GV{server}->cmode_letter('op');
            server::outgoing::cmode_all($user->{server}, $channel, $time, $utils::GV{server}{sid}, "+$owner$op $$user{uid} $$user{uid}");
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

    $user->numeric('RPL_YOUREOPER');
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
    $user->server_notice('List of available commands');

    # send a notice for each command
    foreach my $command (keys %user::mine::commands) {
        foreach my $source (keys %{$user::mine::commands{$command}}) {
            $user->server_notice(sprintf "%s [\2%s\2] %s", $command,
              $source, $user::mine::commands{$command}{$source}{desc})
        }
    }

    $user->server_notice('End of commands list');
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

    $user->{conn}->done("Quit: $reason");
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

1
