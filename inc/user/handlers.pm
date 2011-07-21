#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::handlers;

use warnings;
use strict;
use feature 'switch';

use utils qw[col log2 lceq lconf];

my %commands = (
    PING => {
        params => 1,
        code   => \&ping
    },
    USER => {
        params => 0,
        code   => \&fake_user
    },
    MOTD => {
        params => 0,
        code   => \&motd
    },
    NICK => {
        params => 1,
        code   => \&nick
    },
    PONG => {
        params => 0,
        code   => sub { }
    },
    INFO => {
        params => 0,
        code   => \&info
    },
    MODE => {
        params => 2,
        code   => \&mode
    },
    PRIVMSG => {
        params => 2,
        code   => \&privmsgnotice
    },
    NOTICE => {
        params => 2,
        code   => \&privmsgnotice
    },
    MAP => {
        params => 0,
        code   => \&cmap
    },
    JOIN => {
        params => 1,
        code   => \&cjoin
    },
    NAMES => {
        params => 1,
        code   => \&names
    },
    OPER => {
        params => 2,
        code   => \&oper
    }
);

log2("registering core user handlers");
user::mine::register_handler('core', $_, $commands{$_}{params}, $commands{$_}{code}) foreach keys %commands;
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

    # tell ppl
    $user->sendfrom($user->full, "NICK $newnick");
    my %sent = ( $user => 1);
    foreach my $channel (values %channel::channels) {
        next unless $channel->has_user($user);
        foreach my $usr (@{$channel->{users}}) {
            next unless $usr->is_local;
            next if $sent{$usr};
            $usr->sendfrom($user->full, "NICK $newnick");
            $sent{$usr} = 1
        }
    }

    # change it
    $user->change_nick($newnick);

    server::outgoing::nickchange_all($user);
}

sub info {
    my $user = shift;
    my @info = (
        "",
        "\2***\2 this is \2juno-ircd\2 version \0023.".main::VERSION."\2.\2 ***\2",
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
        my $result = $user->handle_mode_string($args[2]);
        return if $result =~ m/^(\-|\+)$/;
        $user->sendfrom($user->full, "MODE $$user{nick} $result");
        server::outgoing::umode_all($user, $result);
        return 1
    }

    # is it a channel, then?
    if (my $channel = channel::lookup_by_name($args[1])) {
        # TODO
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

        # make sure it's a valid name
        if (!utils::validchan($chname)) {
            $user->numeric('ERR_NOSUCHCHANNEL', $chname);
            next
        }

        # if the channel exists, just join
        my $channel = channel::lookup_by_name($chname);
        my $time = time;

        # otherwise create a new one
        if (!$channel) {
            $channel = channel->new({
                name   => $chname,
                'time' => $time
            });
        }
        return if $channel->has_user($user);
        $channel->channel::mine::join($user, $time);
        server::outgoing::join_all($user, $channel, $time);
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

    my $crypt = lconf('oper', $args[1], 'encryption');

    # so now let's check if the password is right
    given ($crypt) {
        when ('sha1')   { $supplied = Digest::SHA::sha1_hex($supplied)   }
        when ('sha224') { $supplied = Digest::SHA::sha224_hex($supplied) }
        when ('sha256') { $supplied = Digest::SHA::sha256_hex($supplied) }
        when ('sha384') { $supplied = Digest::SHA::sha384_hex($supplied) }
        when ('sha512') { $supplied = Digest::SHA::sha512_hex($supplied) }
        when ('md5')    { $supplied = Digest::MD5::md5_hex($supplied)    }
    }

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
        $user->sendfrom($user->full, "MODE $$user{nick} $result");
    }

    $user->numeric('RPL_YOUREOPER');
    return 1
}

1
