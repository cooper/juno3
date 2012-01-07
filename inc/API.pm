# Copyright (c) 2012, Mitchell Cooper
package API;

use warnings;
use strict;
use feature 'switch';

use utils qw(conf log2 gv set);

# load modules in the configuration
sub load_config {

    log2('Loading core modules');

    # load core modules
    if (my $core = conf('modules', 'core')) {
        load_module("core/$_", "core/$_.pm") foreach @$core;
    }

    log2('Loading extension modules');

    # load extension modules
    if (my $ext = conf('modules', 'ext')) {
        load_module("ext/$_", "ext/$_.pm") foreach @$ext;
    }

    log2('Done loading modules');

}

sub load_module {

    # if we haven't already, load API::Module
    if (!$INC{'API/Module.pm'}) {
        require API::Module
    }

    # load the module
    log2('Loading module '.shift());
    my $file   = $main::run_dir.q(/mod/).shift();
    my $module = do $file or log2("couldn't load $file: $@") and return;

    # make sure it returned properly.
    # even though this is unsupported nowadays, it is
    # still the easiest way to prevent a fatal error
    if (!UNIVERSAL::isa($module, 'API::Module')) {
        log2('Module did not return an API::Module object.');
        return
    }

    # load the requirements if they are not already
    load_requirements($module) or log2('could not satisfy dependencies') and return;

    log2('Module loaded successfully');
}

sub load_requirements {
    my $mod = shift;
    return unless $mod->{requires};
    return if ref $mod->{requires} ne 'ARRAY';

    foreach (@{$mod->{requires}}) {
        when ('user_commands') { load_base('UserCommands');              }
        default                { log2('unknown requirement '.$_); return }
    }

    return 1
}

sub load_base {
    my $base = shift;
    return if $INC{"API/Base/$base.pm"}; # already loaded
    require "API/Base/$base.pm";
    unshift @API::Module::ISA, "API::Base::$base"
}

1
