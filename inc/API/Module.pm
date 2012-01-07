# Copyright (c) 2012, Mitchell Cooper
package API::Module;

use warnings;
use strict;

use utils qw(log2);

our @ISA;

sub new {
    my ($class, %opts) = @_;
    $opts{requires} ||= [];

    # make sure all required options are present
    foreach my $what (qw|name version description|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        log2("module $opts{name} does not have '$what' option.");
        return
    }

    return bless my $mod = \%opts, $class;
}

1
