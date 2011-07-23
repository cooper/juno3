#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package user::numerics;

use warnings;
use strict;

use utils qw/conf log2/;

my %numerics = (
    RPL_WELCOME          => ['001', 'Welcome to the %s IRC Network %s!%s@%s'],
    RPL_YOURHOST         => ['002', ':Your host is %s, running version %s'],
    RPL_CREATED          => ['003', ':This server was created %s'],
    RPL_MYINFO           => ['004', '%s %s %s %s'],
    RPL_ISUPPORT         => ['005', '%s:are supported by this server'],
    RPL_MAP              => ['015', ':%s'],
    RPL_MAPEND           => ['017', ':End of /MAP'],
    RPL_LUSERCLIENT      => ['251', ':There are %d users and %d invisible on %d servers'],
    RPL_LUSEROP          => ['252', '%d :operators online'], # non-zero
    RPL_LUSERUNKNOWN     => ['253', '%d :unknown connections'],
    RPL_LUSERCHANNELS    => ['254', '%d :channels formed'],
    RPL_LUSERME          => ['255', 'I have %d clients and %d servers'],
    RPL_LOCALUSERS       => ['265', '%d %d :Current local users %d, max %d'],
    RPL_GLOBALUSERS      => ['266', '%d %d :Current global users %d, max %d'],
    RPL_ISON             => ['303', ':%s'],
    RPL_UNAWAY           => ['305', ':You are no longer marked as away'],
    RPL_NOWAWAY          => ['306', ':You are now marked as away'],
    RPL_CREATIONTIME     => ['329', '%s %d'],
    RPL_WHOISUSER        => ['311', '%s %s %s * :%s'],
    RPL_WHOISSERVER      => ['312', '%s %s :%s'],
    RPL_WHOISOPERATOR    => ['313', '%s :is an IRC operator'],
    RPL_ENDOFWHOIS       => ['318', '%s :End of /WHOIS list'],
    RPL_WHOISCHANNELS    => ['319', '%s :%s'],
    RPL_NAMEREPLY        => ['353', '%s %s :%s'],
    RPL_ENDOFNAMES       => ['366', '%s :End of /NAMES list'],
    RPL_INFO             => ['372', ':%s'],
    RPL_MOTD             => ['372', ':- %s'],
    RPL_ENDOFINFO        => ['374', 'End of /INFO list'],
    RPL_MOTDSTART        => ['375', ':%s message of the day'],
    RPL_ENDOFMOTD        => ['376', ':End of message of the day'],
    RPL_WHOISMODES       => ['379', '%s :is using modes %s'],
    RPL_WHOISHOST        => ['378', '%s :is connecting from *@%s %s'],
    RPL_YOUREOPER        => ['381', ':You are now an IRC operator'],
    ERR_NOSUCHNICK       => ['401', '%s :No such nick/channel'],
    ERR_NOSUCHCHANNEL    => ['403', '%s :No such channel'],
    ERR_NOTEXTTOSEND     => ['412', ':No text to send'],
    ERR_UNKNOWNCOMMAND   => ['421', '%s :Unknown command'],
    ERR_NOMOTD           => ['422', ':MOTD file is missing'],
    ERR_ERRONEUSNICKNAME => ['432', '%s: Erroneous nickname'],
    ERR_NICKNAMEINUSE    => ['433', '%s :Nickname in use'],
    ERR_NEEDMOREPARAMS   => ['461', '%s :Not enough parameters'],
    ERR_ALREADYREGISTRED => ['462', ':You may not reregister'],
    ERR_NOOPERHOST       => ['491', ':No oper blocks for your host'],
    ERR_USERSDONTMATCH   => ['502', ':Can\'t change mode for other users']
);

log2("registering core numerics");
user::mine::register_numeric('core', $_, $numerics{$_}[0], $numerics{$_}[1]) foreach keys %numerics;
log2("end of core numerics");

sub rpl_isupport {
    my $user = shift;

    my %things = (
        PREFIX      => '(qaohv)~&@%+',              # TODO 
        CHANTYPES   => '#',                         # TODO
        CHANMODES   => ',,,',                       # TODO
        MODES       => 0,                           # TODO
        CHANLIMIT   => '#:0',                       # TODO
        NICKLEN     => conf('limit', 'nick'),
        MAXLIST     => 'beIZ:0',                    # TODO
        NETWORK     => $utils::GV{network},
        EXCEPTS     => 'e',
        INVEX       => 'I',
        CASEMAPPING => 'rfc1459',
        TOPICLEN    => conf('limit', 'topic'),
        KICKLEN     => conf('limit', 'kickmsg'),
        CHANNELLEN  => conf('limit', 'channelname'),
        RFC2812     => 'YES',
        FNC         => 'YES',
        AWAYLEN     => conf('limit', 'away'),
        MAXTARGETS  => 1                            # TODO
      # ELIST                                       # TODO
    );

    my @lines = '';
    my $curr = 0;

    while (my ($param, $val) = each %things) {
        if (length $lines[$curr] > 135) {
            $curr++;
            $lines[$curr] = ''
        }
        $lines[$curr] .= ($val eq 'YES' ? $param : $param.q(=).$val).q( )
    }

    $user->numeric('RPL_ISUPPORT', $_) foreach @lines
}

1

