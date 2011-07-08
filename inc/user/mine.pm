#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
# this handles local user input
package user::mine;

use warnings;
use strict;

use utils qw[col log2];

my (%numerics, %commands);

# register command handlers
sub register_handler {
    my $command = uc shift;

    # does it already exist?
    if (exists $commands{$command}) {
        log2("attempted to register $command which already exists");
        return
    }

    my $params = shift;

    # ensure that it is CODE
    my $ref = shift;
    if (ref $ref ne 'CODE') {
        log2("not a CODE reference for $command");
        return
    }

    # success
    $commands{$command} = {
        code    => $ref,
        params  => $params
    };
    log2((caller)[0]." registered $command");
    return 1
}

# register user numerics
sub register_numeric {
    my $numeric = shift;

    # does it already exist?
    if (exists $numerics{$numeric}) {
        log2("attempted to register $numeric which already exists");
        return
    }

    my ($num, $str) = (shift, shift);
    $numerics{$numeric} = [$num, $str];
    log2((caller)[0]." registered $numeric $num");
    return 1
}

sub handle {
    my $user = shift;
    foreach my $line (split "\n", shift) {

        my @s = split /\s+/, $line;

        if ($s[0] =~ m/^:/) { # lazy way of deciding if there is a source provided
            shift @s
        }

        my $command = uc $s[0];

        if ($commands{$command}) { # an existing handler
            if ($#s >= $commands{$command}{params}) {
                $commands{$command}{code}($user, $line, @s)
            }
            else { # not enough parameters
                $user->numeric('ERR_NEEDMOREPARAMS', $s[0])
            }
        }
        else { # unknown command
            $user->numeric('ERR_UNKNOWNCOMMAND', $s[0])
        }

    }
    return 1
}

sub send {
    my $user = shift;
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    $user->{conn}->send(@_)
}

# send data with a source
sub sendfrom {
    my ($user, $source) = (shift, shift);
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    my @send = ();
    foreach my $line (@_) {
        push @send, ":$source $line"
    }
    $user->{conn}->send(@send)
}

# send data with this server as the source
sub sendserv {
    my $user = shift;
    if (!$user->{conn}) {
        my $sub = (caller 1)[3];
        log2("can't send data to a nonlocal user! please report this error by $sub. $$user{nick}");
        return
    }
    my @send = ();
    foreach my $line (@_) {
        push @send, ":$utils::GV{servername} $line"
    }
    $user->{conn}->send(@send)
}

sub numeric {
    my ($user, $num) = (shift, shift);
    if (exists $numerics{$num}) {
        $user->sendserv($numerics{$num}[0]." $$user{nick} ".sprintf($numerics{$num}[1], @_));
        return 1
    }
    log2("attempted to send nonexistent numeric $num");
    return
}

# send welcomes
sub new_connection {
    my $user = shift;
    $user->numeric('RPL_WELCOME', $utils::GV{network}, $user->{nick}, $user->{ident}, $user->{host});
    $user->numeric('RPL_YOURHOST', $utils::GV{servername}, $main::VERSION);
    $user->numeric('RPL_CREATED', POSIX::strftime('%a %b %d %Y at %H:%M:%S %Z', localtime $main::START));
    $user->numeric('RPL_MYINFO', $utils::GV{servername}, $main::VERSION, 'i', 'i'); # TODO
    $user->user::numerics::rpl_isupport();
    $user->handle('LUSERS');
    $user->handle('MOTD')
}

1
