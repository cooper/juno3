#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package utils;

use warnings;
use strict;
use feature qw[switch say];
use base 'Exporter';

use Exporter;

our @EXPORT_OK = qw[log2 conf fatal col conn trim];
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
        if ($line =~ m/^\[(.*):(.*)\]$/) {
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
            print "key: $key\nval: $val\n";
            $conf{$block}{$name}{$key} = $val;
        }

        else {
            die "Invalid line $i of $file\n"
        }

    }

    # set some global variables
    $utils::GV{servername} = conf('server', 'name');
    $utils::GV{serverid}   = conf('server', 'id');
    $utils::GV{serverdesc} = conf('server', 'description');

    return 1

}

# fetch a configuration file

sub conf {
    my ($sec, $key) = @_;
    return $conf{sec}{$sec}{$key} if exists $conf{sec}{$sec}{$key};
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
    say(time.($sub ? " $sub(): " : q[ ]).$line)
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

# remove leading and trailing whitespace

sub trim {
    my $string = shift;
    $string =~ s/\s+$//;
    $string =~ s/^\s+//;
    return $string
}

1
