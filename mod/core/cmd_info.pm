# Copyright (c) 2012, Mitchell Cooper
package ext::core::cmd_info;

use warnings;
use strict;

use utils 'gv';

our $mod = API::Module->new(
    name        => 'core/cmd_info',
    version     => '0.1',
    description => 'display ircd license and credits',
    requires    => ['user_commands'],
    initialize  => \&init
);

sub init {
    $mod->register_user_command(
        name        => 'info',
        description => 'display ircd license and credits',
        code        => \&info
    )
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

$mod
