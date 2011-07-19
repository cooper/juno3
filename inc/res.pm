#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package res;

use warnings;
use strict;

use Net::IP;
use Net::DNS;
use utils qw/log2/;

sub resolve_finish {
    my ($connection, $host) = @_;
    if (!defined $host) {
        log2("could not resolve $$connection{ip}");
        $connection->{host} = $connection->{ip};
        delete $connection->{res_start};
        $connection->send(':'.$utils::GV{servername}.' NOTICE * :*** Could not resolve your hostname; using IP address instead')
    }
    else {
        log2("$$connection{ip} -> $host");
        $connection->{host} = $host;
        my $time = time - $connection->{res_start};
        $connection->send(':'.$utils::GV{servername}.' NOTICE * :*** Found your hostname in '.$time.'s ('.$host.')')
    }
    $connection->ready if $connection->somewhat_ready;
    return 1
}

sub resolve_hostname {
    my $connection = shift;
    my $res = Net::DNS::Resolver->new;
    my $bg = $res->bgsend($connection->{ip}, 'PTR');
    main::register_loop('PTR lookup for '.$connection->{ip}, sub {
        resolve_ptr(shift, $res, $bg, $connection);
    });
}

sub resolve_ptr {
    my ($loop, $res, $bg, $connection) = @_;
    return unless $res->bgisready($bg);
    my $packet = $res->bgread($bg);
    undef $bg;
    if (!defined $packet) {
        # error
        main::delete_loop($loop);
        $connection->res::resolve_finish($connection->{ip});
        return
    }

    # no error; keep going
    my @rr = $packet->answer;

    # check if there is 1 record - no less, no more
    if (scalar @rr != 1) {
        main::delete_loop($loop);
        $connection->res::resolve_finish(undef);
        return
    }

    # found an rDNS. now check if it resolves to the IP address
    my $result = $rr[0]->ptrdname;
    main::delete_loop($loop);
    my $type  = (Net::IP::ip_is_ipv6($connection->{ip}) ? 'AAAA' : 'A');
    my $check = $res->bgsend($result, $type);
    main::register_loop($type.' lookup for '.$result, sub {
        resolve_aaaaa(shift, $res, $check, $connection, $result)
    });
}

sub resolve_aaaaa {
    my ($loop, $res, $bg, $connection, $result) = @_;
    return unless $res->bgisready($bg);
    my $packet = $res->bgread($bg);
    undef $bg;
    if (!defined $packet) {
        # error
        main::delete_loop($loop);
        $connection->res::resolve_finish(undef);
        return
    }

    # no error; keep going
    my @rr = $packet->answer;

    # check if there is 1 record - no less, no more
    if (scalar @rr != 1) {
        main::delete_loop($loop);
        $connection->res::resolve_finish(undef);
        return
    }

    # only accept A and AA
    if (!$rr[0]->isa('Net::DNS::RR::A') && !$rr[0]->isa('Net::DNS::RR::AAAA')) {
        main::delete_loop($loop);
        $connection->res::resolve_finish(undef);
        return
    }

    my $addr = $rr[0]->address;
    my $ip   = $connection->{ip};

    # compress them if it is IPv6
    if (Net::IP::ip_is_ipv6($addr)) {
        $addr = Net::IP::ip_compress_address($addr, 6);
        $ip   = Net::IP::ip_compress_address($ip, 6);
    }

    # found a record, does it match the IP address?
    if ($addr eq $ip) {
        # they match! set their host to that domain
        main::delete_loop($loop);
        $connection->res::resolve_finish($result);
        return 1
    }

    # they don't match :(
    main::delete_loop($loop);
    $connection->res::resolve_finish(undef);
    return
}

1
