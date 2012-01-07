# Copyright (c) 2012, Mitchell Cooper
package API;

use warnings;
use strict;
use feature 'switch';

use utils qw(conf log2 gv set);

our @loaded;

# load modules in the configuration
sub load_config {
    log2('Loading configuration modules');
    if (my $mods = conf('api', 'modules')) {
        load_module($_, "$_.pm") foreach @$mods;
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

    # initialize
    log2('initializing module');
    $module->{initialize}->() or log2('module refused to load.') and return;

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

sub call_unloads {
    my $module = shift;
    $_->unload($module) foreach @API::Module::ISA;
}

1
