#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::handlers;

use warnings;
use strict;
use utils qw[col log2 lceq];

my %commands = (
    PING => {
        params => 1,
        code   => \&ping
    },
    USER => {
        params => 0,
        code   => \&fake_user
    },
    LUSERS => {
        params => 0,
        code   => \&lusers
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
        code   => \&privmsg
    },
    MAP => {
        params => 0,
        code   => \&cmap
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

sub lusers {
    my $user = shift;
    my ($users, $invisible, $opers, $myclients, $myservers, $unknown) = 0;
    $invisible = $opers = $myclients = $myservers = $unknown = $users;

    foreach my $connection (values %connection::connection) {
        if (!exists $connection->{type}) {
            $unknown++;
            next
        }
        elsif ($connection->{type}->isa('server')) {
            $myservers++;
            next
        }
        elsif ($connection->{type}->isa('user')) {
            $myclients++;
            next
        }
        else {
            $unknown++
        }
    }

    foreach my $usr (values %user::user) {
        # TODO opers
        # TODO invisible
        $users++
    }

    $user->numeric('RPL_LUSERCLIENT', $users, $invisible, scalar keys %server::server);
    $user->numeric('RPL_LUSEROP', $opers) if $opers;

    # only send if non-zero
    my $channels = scalar keys %channel::channels;
    $user->numeric('RPL_LUSERCHANNELS', $channels) if $channels;

    $user->numeric('RPL_LUSERME', $myclients, $myservers);
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

    # TODO send to familiar users
    # but for now just send to the client

    $user->sendfrom($user->full, "NICK $newnick");
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

sub privmsg {
    my ($user, $data, @args) = @_;

    # we can't  use @args because it splits by whitespace
    $data =~ s/^:(.+)\s//;
    my @m = split ' ', $data, 3;
    my $message = col($m[2]);

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
            $tuser->sendfrom($user->full, "PRIVMSG $$tuser{nick} :$message");
        }

        # send it to the server holding this user
        else {
            $tuser->{location}->server::outgoing::privmsg($user, $tuser->{uid}, $message);
        }
        return 1
    }

    # must be a channel
    my $channel = channel::lookup_by_name($args[1]);
    if ($channel) {
        return 1 # TODO
    }

    # no such nick/channel
    $user->numeric('ERR_NOSUCHNICK', $args[1]);
    return
}

sub cmap {
    # TODO this will be much prettier later!
    my $user  = shift;
    foreach my $server (values %server::server) {
        $user->numeric('RPL_MAP', '    '.$server->{name})
    }
    $user->numeric('RPL_MAPEND');
}

1
