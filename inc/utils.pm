#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package utils;

use warnings;
use strict;
use feature qw[switch say];
use base 'Exporter';

use Exporter;

our @EXPORT_OK = qw[log2 conf fatal col conn];
our (%conf, %GV);

# parse a configuration file

sub parse_config {

    my ($file, $fh) = shift;

    if (not open $fh, '<', $file) {
        log2("Couldn't open configuration $file: ".($@ ? $@ : $!));
        return
    }

    my ($i, $block, $section) = 0;

    while (my $line = <$fh>) {

        $i++;

        # remove prefixing and suffixing whitespace
        $line =~ s/\s+$//;
        $line =~ s/^\s+//;

        # ignore comments
        next unless $line;
        next if $line =~ m/^(#|\/\/)/;

        my @word = split /\s+/, $line, 4;

        given ($word[0]) {

            when ('[') {
                if (!defined $word[3]) {
                    log2("Syntax error on line $i of configuration $file: $line");
                    next
                }
                $block = $word[1];
                $block =~ s/:$//;
                $section = $word[2]
            }
            when ('*') {

                if (!defined $word[3]) {
                    log2("Syntax error on line $i of configuration $file: $line");
                    next
                }

                if (!$block or !$section) {
                    log2("No block/section set in configuration on line $line");
                    next
                }

                $conf{$block}{$section}{$word[1]} = $word[3]

            }
            default {
                log2("Unable to parse line $i of $file: $line")
            }
        }

    }

    # set some global variables
    $utils::GV{servername} = conf('server', 'name');
    $utils::GV{serverid} = conf('server', 'id');
    $utils::GV{serverdesc} = conf('server', 'desc');

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

1
