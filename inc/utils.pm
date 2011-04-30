#!/usr/bin/perl
package utils;

use warnings;
use strict;
use feature 'switch';
use base 'Exporter';

use Exporter;

our @EXPORT_OK = qw[log2 conf];
our %conf;

# parse a configuration file

sub parse_config {

    my ($file, $fh) = shift;

    if (not open $fh, '<', $file) {
        log2("Couldn't open configuration $file: ".($@ ? $@ : $!));
        return
    }

    my $i = 0;

    while (my $line = <$fh>) {

        $i++;

        # remove prefixing and suffixing whitespace

        $line =~ s/\s+$//;
        $line =~ s/^\s+//;

        # ignore comments
        next if $line =~ m/^(#|\/\/)/;

        my @word = split /\s+/, $line, 3;
        my ($block, $section);

        given ($word[0]) {
            when (/^(oper|kline|dline|listen)$/) {
                $block = $word[0];
                $section = $word[1]
            }
            when ('*') {

                if (!$block or !$section) {
                    log2("No block/section set in configuration on line $line");
                    next
                }

                $conf{$block}{$section}{$word[1]} = $word[2]

            }
            default {
                log2("Unable to parse line $i of $file: $line")
            }
        }

    }

    return 1

}

# fetch a configuration file

sub conf {
    my ($sec, $key) = @_;
    return $conf{sec}{$sec}{$key} if exists $conf{sec}{$sec}{$key};
    return
}

# log errors/warnings

sub log2 {
    my $line = shift;
    my $sub = (caller 1)[3];
    say(time.($sub ? " $sub(): " : q[ ]).$line)
}

1
