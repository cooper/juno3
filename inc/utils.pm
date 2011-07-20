#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package utils;

use warnings;
use strict;
use feature qw[switch say];
use base 'Exporter';
use Exporter;

our @EXPORT_OK = qw[log2 conf lconf fatal col conn trim lceq match];
our (%conf, %GV);

# parse a configuration file

sub parse_config {

    my ($file, $fh) = shift;
    open my $config, '<', $file or die "$!\n";
    my ($i, $block, $name, $key, $val) = 0;
    while (my $line = <$config>) {

        $i++;
        $line = trim($line);
        next unless $line;
        next if $line =~ m/^#/;

        # a block with a name
        if ($line =~ m/^\[(.*?):(.*)\]$/) {
            $block = trim($1);
            $name  = trim($2);
        }

        # a nameless block
        elsif ($line =~ m/^\[(.*)\]$/) {
            $block = 'sec';
            $name  = trim($1);
        }

        # a key and value
        elsif ($line =~ m/^(\s*)(\w*):(.*)$/ && defined $block) {
            $key = trim($2);
            $val = eval trim($3);
            die "Invalid value in $file line $i: $@" if $@;
            $conf{$block}{$name}{$key} = $val;
        }

        else {
            die "Invalid line $i of $file\n"
        }

    }

    open my $motd, conf('file', 'motd');
    if (!eof $motd) {
        while (my $line = <$motd>) {
            chomp $line;
            push @{$utils::GV{motd}}, $line
        }
    }
    else {
        $utils::GV{motd} = undef
    }

    # set some global variables
    $utils::GV{servername} = conf('server', 'name');
    $utils::GV{serverid}   = conf('server', 'id');
    $utils::GV{serverdesc} = conf('server', 'description');
    $utils::GV{network}    = conf('network', 'name');

    return 1

}

# fetch a configuration file

sub conf {
    my ($sec, $key) = @_;
    return $conf{sec}{$sec}{$key} if exists $conf{sec}{$sec}{$key};
    return
}

sub lconf { # for named blocks
    my ($block, $sec, $key) = @_;
    return $conf{$block}{$sec}{$key} if exists $conf{$block}{$sec}{$key};
    return
}

sub conn {
    my ($sec, $key) = @_;
    return $conf{connect}{$sec}{$key} if exists $conf{connect}{$sec}{$key};
    return
}

# log errors/warnings

sub log2 {
    my $line = shift;
    my $sub = (caller 1)[3];
    say(time.q( ).($sub && $sub ne '(eval)' ? "$sub():" : q([).(caller)[0].q(])).q( ).$line)
}

# log and exit

sub fatal {
    my $line = shift;
    my $sub = (caller 1)[3];
    log2(($sub ? "$sub(): " : q..).$line);
    exit(shift() ? 0 : 1)
}

# remove a prefixing colon

sub col {
    my $string = shift;
    $string =~ s/^://;
    return $string
}

# find an object by it's id (server, user) or channel name
sub global_lookup {
    my $id = shift;
    my $server = server::lookup_by_id($id);
    my $user   = user::lookup_by_id($id);
    my $chan   = channel::lookup_by_name($id);
    return $server ? $server : ( $user ? $user : ( $chan ? $chan : undef ) )
}

# remove leading and trailing whitespace

sub trim {
    my $string = shift;
    $string =~ s/\s+$//;
    $string =~ s/^\s+//;
    return $string
}

# check if a nickname is valid
sub validnick {
    my $str   = shift;
    my $limit = conf('limit', 'nick');

    # valid characters
    return if (length $str < 1 ||
      length $str > $limit ||
      ($str =~ m/^\d/) ||
      $str =~ m/[^A-Za-z-0-9-\[\]\\\`\^\|\{\}\_]/);

    # success
    return 1

}

# check if a channel name is valid
sub validchan {
    my $name = shift;
    return if length $name > conf('limit', 'channelname');
    return unless $name =~ m/^#/;
    return 1
}

# match a host to a list
sub match {
    my ($mask, @list) = @_;
    $mask = lc $mask;
    my @aregexps;

    foreach my $regexp (@list) {

        # replace wildcards with regex
        $regexp =~ s/\./\\\./g;
        $regexp =~ s/\?/\./g;
        $regexp =~ s/\*/\.\*/g;
        $regexp = '^'.$regexp.'$';
        push @aregexps, lc $regexp

    }

    # success
    return 1 if grep { $mask =~ m/$_/ } @aregexps;

    # no matches
    return

}

sub lceq {
    lc shift eq lc shift
}

# for configuration values
sub on  () { 1 }
sub off () { 0 }

1
