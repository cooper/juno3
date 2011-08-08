#!/usr/bin/perl
# Copyright (c) 2011, Mitchell Cooper
package connection;

use warnings;
use strict;
use feature 'switch';

use utils qw[log2 col conn conf match gv];

our ($ID, %connection) = 0;

sub new {
    my ($this, $peer) = @_;
    return unless defined $peer;

    bless my $connection = {
        obj           => $peer,
        ip            => $peer->peerhost,
        source        => gv('SERVER', 'sid'),
        last_ping     => time,
        time          => time,
        last_response => time
    }, $this;

    # resolve hostname
    if (conf qw/enabled resolve/) {
        $connection->send(':'.gv('SERVER', 'name').' NOTICE * :*** Looking up your hostname...');
        res::resolve_hostname($connection)
    }
    else {
        $connection->{host} = $connection->{ip};
        $connection->send(':'.gv('SERVER', 'name').' NOTICE * :*** hostname resolving is not enabled on this server')
    }

    log2("Processing connection from $$connection{ip}");    
    $main::select->add($peer);
    return $connection{$peer} = $connection
}

sub handle {
    my ($connection, $data) = @_;

    $connection->{ping_in_air}   = 0;
    $connection->{last_response} = time;

    # strip unwanted characters
    $data =~ s/(\n|\r|\0)//g;

    # if this peer is registered, forward the data to server or user
    return $connection->{type}->handle($data) if $connection->{ready};

    my @args = split /\s+/, $data;
    return unless defined $args[0];

    given (uc shift @args) {

        when ('NICK') {

            # not enough parameters
            return $connection->wrong_par('NICK') if not defined $args[0];

            my $nick = col(shift @args);

            # nick exists
            if (user::lookup_by_nick($nick)) {
                $connection->send(':'.gv('SERVER', 'name')." 433 * $nick :Nickname is already in use.");
                return
            }

            # invalid chars
            if (!utils::validnick($nick)) {
                $connection->send(':'.gv('SERVER', 'name')." 432 * $nick :Erroneous nickname");
                return
            }

            # set the nick
            $connection->{nick} = $nick;

            # the user is ready if their USER info has been sent
            $connection->ready if exists $connection->{ident} && exists $connection->{host}

        }

        when ('USER') {

            # set ident and real name
            if (defined $args[3]) {
                $connection->{ident} = $args[0];
                $connection->{real}  = col((split /\s+/, $data, 5)[4])
            }

            # not enough parameters
            else {
                return $connection->wrong_par('USER')
            }

            # the user is ready if their NICK has been sent
            $connection->ready if exists $connection->{nick} && exists $connection->{host}

        }

        when ('SERVER') {

            # parameter check
            return $connection->wrong_par('SERVER') if not defined $args[4];


            $connection->{$_}   = shift @args foreach qw[sid name proto ircd];
            $connection->{desc} = col(join ' ', @args);

            # if this was by our request (as in an autoconnect or /connect or something)
            # don't accept any server except the one we asked for.
            if (exists $connection->{want} && lc $connection->{want} ne lc $connection->{name}) {
                $connection->done('unexpected server');
                return
            }

            # find a matching server

            if (defined ( my $addr = conn($connection->{name}, 'address') )) {

                # check for matching IPs

                if (!match($connection->{ip}, $addr)) {
                    $connection->done('Invalid credentials');
                    return
                }

            }

            # no such server

            else {
                $connection->done('Invalid credentials');
                return
            }

            # if a password has been sent, it's ready
            $connection->ready if exists $connection->{pass} && exists $connection->{host}

        }

        when ('PASS') {

            # parameter check
            return $connection->wrong_par('PASS') if not defined $args[0];

            $connection->{pass} = shift @args;

            # if a server has been sent, it's ready
            $connection->ready if exists $connection->{name} && exists $connection->{host}

        }

        when ('QUIT') {
            my $reason = 'leaving';

            # get the reason if they specified one
            if (defined $args[1]) {
                $reason = col((split /\s+/,  $data, 2)[1])
            }

            $connection->done("Quit: $reason");
        }

    }
}

# post-registration

sub wrong_par {
    my ($connection, $cmd) = @_;
    $connection->send(':'.gv('SERVER', 'name').' 461 '
      .($connection->{nick} ? $connection->{nick} : '*').
      " $cmd :Not enough parameters");
    return
}

sub ready {
    my $connection = shift;

    # must be a user
    if (exists $connection->{nick}) {
        $connection->{uid}      = gv('SERVER', 'sid').++$ID;
        $connection->{server}   = gv('SERVER');
        $connection->{location} = gv('SERVER');
        $connection->{cloak}    = $connection->{host};
        $connection->{modes}    = '';
        $connection->{type}     = user->new($connection);

        # tell my children
        
    }

    # must be a server
    elsif (exists $connection->{name}) {

        # check for valid password.
        my $password = utils::crypt($connection->{pass}, conn($connection->{name}, 'encryption'));

        if ($password ne conn($connection->{name}, 'receive_password')) {
            $connection->done('Invalid credentials');
            return
        }

        $connection->{parent} = gv('SERVER');
        $connection->{type}   = server->new($connection);
        server::outgoing::sid_all($connection->{type});

        # send server credentials
        if (!$connection->{sent_creds}) {
            $connection->send(sprintf 'SERVER %s %s %s %s :%s', gv('SERVER', 'sid'), gv('SERVER', 'name'), gv('PROTO'), gv('VERSION'), gv('SERVER', 'desc'));
            $connection->send('PASS '.conn($connection->{name}, 'send_password'))
        }

        $connection->send('READY');

    }

    
    else {
        # must be an intergalactic alien
    }
    
    # memory leak (fixed)
    $connection->{type}->{conn} = $connection;
    user::mine::new_connection($connection->{type}) if $connection->{type}->isa('user');
    return $connection->{ready} = 1

}

sub somewhat_ready {
    my $connection = shift;
    if (exists $connection->{nick} && exists $connection->{ident}) {
        return 1
    }
    if (exists $connection->{name} && exists $connection->{pass}) {
        return 1
    }
    return
}

# send data to the socket
sub send {
    return main::sendpeer(shift->{obj}, @_)
}

# find by a user or server object

sub lookup {
    my $obj = shift;
    foreach my $conn (values %connection) {
        # found a match
        return $conn if $conn->{type} == $obj
    }

    # no matches
    return
}

# find by a socket handle
sub lookup_by_handle {
    my $socket = shift;
    return $connection{$socket};
}

# end a connection

sub done {

    my ($connection, $reason, $silent) = @_;

    log2("Closing connection from $$connection{ip}: $reason");

    if ($connection->{type}) {
        # share this quit with the children
        $connection->server::outgoing::quit_all($reason);

        # tell user.pm or server.pm that the connection is closed
        $connection->{type}->quit($reason)
    }

    $connection->{obj}->syswrite("ERROR :Closing Link: $$connection{ip} ($reason)\r\n", POSIX::BUFSIZ) unless $silent;

    # remove from connection list
    delete $connection{$connection->{obj}};

    $main::select->remove($connection->{obj});
    $connection->{obj}->close;

    # fixes memory leak:
    # referencing to ourself, etc.
    # perl doesn't know to destroy unless we do this
    delete $connection->{type}->{conn};
    delete $connection->{type};

    return 1

}

sub DESTROY {
    my $connection = shift;
    log2("$connection destroyed");
}

1
