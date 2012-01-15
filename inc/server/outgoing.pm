#!/usr/bin/perl
# Copyright (c) 2010-12, Mitchell Cooper
# contains outgoing commands
package server::outgoing;

use warnings;
use strict;
use feature 'switch';

use utils qw(gv);

###########
# servers #
###########

sub quit_all {
    my ($connection, $reason) = @_;
    server::mine::sendfrom_children(undef, $connection->{type}->id, 'QUIT :'.$reason)
}

sub sid {
    my ($server, $serv) = @_;
    $server->sendfrom($serv->{parent}->{sid}, sprintf
        'SID %s %d %s %s %s :%s',
          $serv->{sid}, $serv->{time}, $serv->{name},
          $serv->{proto}, $serv->{ircd}, $serv->{desc})
}

sub sid_all {
    my $serv = shift;
    server::mine::sendfrom_children(undef, $serv->{parent}->{sid}, sprintf
        'SID %s %d %s %s %s :%s',
          $serv->{sid}, $serv->{time}, $serv->{name},
          $serv->{proto}, $serv->{ircd}, $serv->{desc})
}

sub addumode {
    my ($server, $serv, $name, $mode) = @_;
    $server->sendfrom($serv->{sid}, "ADDUMODE $name $mode");
}

sub addumode_all {
    my ($serv, $name, $mode) = @_;
    server::mine::sendfrom_children(undef, $serv->{sid}, "ADDUMODE $name $mode");
}

sub addcmode {
    my ($server, $serv, $name, $mode, $type) = @_;
    $server->sendfrom($serv->{sid}, "ADDCMODE $name $mode $type");
}

sub addcmode_all {
    my ($serv, $name, $mode, $type) = @_;
    server::mine::sendfrom_children(undef, $serv->{sid}, "ADDCMODE $name $mode $type");
}

sub topicburst {
    my ($server, $channel) = @_;
    $server->sendfrom(gv('SERVER')->{sid}, sprintf
        'TOPICBURST %s %d %s %d :%s',
          $channel->{name},
          $channel->{time},
          $channel->{topic}->{setby},
          $channel->{topic}->{time},
          $channel->{topic}->{topic})
}

sub topicburst_all {
    my $channel = shift;
    server::mine::sendfrom_children(undef, gv('SERVER')->{sid}, sprintf
        'TOPICBURST %s %d %s %d :%s',
          $channel->{name},
          $channel->{time},
          $channel->{topic}->{setby},
          $channel->{topic}->{time},
          $channel->{topic}->{topic})
}

#########
# users #
#########

# new user

sub uid {
    my ($server, $user) = @_;
    $server->sendfrom($user->{server}->{sid}, sprintf
        'UID %s %d %s %s %s %s %s %s :%s',
          $user->{uid}, $user->{time}, $user->mode_string(),
          $user->{nick}, $user->{ident}, $user->{host},
          $user->{cloak}, $user->{ip}, $user->{real})
}

sub uid_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{server}->{sid}, sprintf
        'UID %s %d %s %s %s %s %s %s :%s',
          $user->{uid}, $user->{time}, $user->mode_string(),
          $user->{nick}, $user->{ident}, $user->{host},
          $user->{cloak}, $user->{ip}, $user->{real})
}

# nick change

sub nickchange {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, "NICK $$user{nick}")
}

sub nickchange_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, "NICK $$user{nick}")
}

# user mode change

sub umode {
    my ($server, $user, $modestr) = @_;
    $server->sendfrom($user->{uid}, "UMODE $modestr")
}

sub umode_all {
    my ($user, $modestr) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "UMODE $modestr")
}

# privmsg and notice

sub privmsgnotice {
    my ($server, $cmd, $user, $target, $message) = @_;
    $server->sendfrom($user->{uid}, "$cmd $target :$message")
}

sub privmsgnotice_all {
    my ($cmd, $user, $target, $message) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "$cmd $target :$message")
}

# channel join

sub sjoin {
    my ($server, $user, $channel, $time) = @_;
    $server->sendfrom($user->{uid}, "JOIN $$channel{name} $time")
}

sub sjoin_all {
    my ($user, $channel, $time) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "JOIN $$channel{name} $time")
}

# add oper flags

sub oper {
    my ($server, $user, @flags) = @_;
    $server->sendfrom($user->{uid}, "OPER @flags")
}

sub oper_all {
    my ($user, @flags) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "OPER @flags")
}

# set away

sub away {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, "AWAY :$$user{away}")
}

sub away_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, "AWAY :$$user{away}")
}

# return from away

sub return_away {
    my ($server, $user) = @_;
    $server->sendfrom($user->{uid}, 'RETURN')
}

sub return_away_all {
    my $user = shift;
    server::mine::sendfrom_children(undef, $user->{uid}, 'RETURN')
}

# leave a channel

sub part {
    my ($server, $user, $channel, $time, $reason) = @_;
    my $sreason = $reason ? " :$reason" : q();
    $server->sendfrom($user->{uid}, "PART $$channel{name} $time$sreason")
}

sub part_all {
    my ($user, $channel, $time, $reason) = @_;
    my $sreason = $reason ? " :$reason" : q();
    server::mine::sendfrom_children(undef, $user->{uid}, "PART $$channel{name} $time$sreason")
}

sub topic {
    my ($server, $user, $channel, $time, $topic) = @_;
    $server->sendfrom($user->{uid}, "TOPIC $$channel{name} $$channel{time} $time :$topic")
}

sub topic_all {
    my ($user, $channel, $time, $topic) = @_;
    server::mine::sendfrom_children(undef, $user->{uid}, "TOPIC $$channel{name} $$channel{time} $time :$topic")
}

########
# both #
########

# channel mode change

sub cmode {
    my ($server, $source, $channel, $time, $perspective, $modestr) = @_;
    $server->sendfrom($source->id, "CMODE $$channel{name} $time $perspective :$modestr")
}

sub cmode_all {
    my ($source, $channel, $time, $perspective, $modestr) = @_;
    server::mine::sendfrom_children(undef, $source->id, "CMODE $$channel{name} $time $perspective :$modestr")
}


####################
# COMPACT commands #
####################

# channel user membership (channel burst)
sub cum {
    my ($server, $channel) = @_;
    # modes are from the perspective of this server, gv:SERVER

    my (%prefixes, @userstrs);

    my (@modes, @user_params, @server_params);
    my @set_modes = sort { $a cmp $b } keys %{$channel->{modes}};

    foreach my $name (@set_modes) {
      my $letter = gv('SERVER')->cmode_letter($name);
      given (gv('SERVER')->cmode_type($name)) {

        # modes with 0 or 1 parameters
        when ([0, 1, 2]) { push @modes, $letter; continue }

        # modes with EXACTLY ONE parameter
        when ([1, 2]) { push @server_params, $channel->{modes}->{$name}->{parameter} }

        # lists
        when (3) {
            foreach my $thing (@{$channel->{modes}->{$name}->{list}}) {
                push @modes,         $letter;
                push @server_params, $thing
            }
        }

        # lists of users
        when (4) {
            foreach my $user (@{$channel->{modes}->{$name}->{list}}) {
                if (exists $prefixes{$user}) { $prefixes{$user} .= $letter }
                                        else { $prefixes{$user}  = $letter }
            } # ugly br
        } # ugly bracke
    } } # ugly brackets 

    # make +modes params string without status modes
    my $modestr = '+'.join(' ', join('', @modes), @server_params);

    # create an array of uid!status
    foreach my $user (@{$channel->{users}}) {
        my $str = $user->{uid};
        $str .= '!'.$prefixes{$user} if exists $prefixes{$user};
        push @userstrs, $str
    }

    # note: use "-" if no users present
    $server->sendfrom(gv('SERVER')->{sid}, "CUM $$channel{name} $$channel{time} ".(join(',', @userstrs) || '-')." :$modestr")
}

# add cmodes
sub acm {
    my ($server, $serv) = @_;
    my @modes;
    foreach my $name (keys %{$serv->{cmodes}}) {
        push @modes, "$name:".$serv->cmode_letter($name).':'.$serv->cmode_type($name)
    }
    $server->sendfrom($serv->{sid}, 'ACM '.join(' ', @modes))
}

# add umodes
sub aum {
    my ($server, $serv) = @_;
    my @modes;
    foreach my $name (keys %{$serv->{umodes}}) {
        push @modes, "$name:".$serv->umode_letter($name)
    }
    $server->sendfrom($serv->{sid}, 'AUM '.join(' ', @modes))
}

1
