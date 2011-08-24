#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2007-2011 -- leonerd@leonerd.org.uk

package Socket::GetAddrInfo;

use strict;
use warnings;

use Carp;

our $VERSION = '0.21';

require Exporter;
our @EXPORT;
our %EXPORT_TAGS;

foreach my $impl (qw( Core XS Emul )) {
   my $class = "Socket::GetAddrInfo::$impl";
   my $file  = "Socket/GetAddrInfo/$impl.pm";
   eval {
      # Each of the impls puts its symbols directly in our package
      # Don't need to ->import
      require $file;
   };

   last if defined &getaddrinfo;
}

=head1 NAME

C<Socket::GetAddrInfo> - RFC 2553's C<getaddrinfo> and C<getnameinfo>
functions.

=head1 SYNOPSIS

 use Socket qw( SOCK_STREAM );
 use Socket::GetAddrInfo qw( :newapi getaddrinfo getnameinfo );
 use IO::Socket;

 my $sock;

 my %hints = ( socktype => SOCK_STREAM );
 my ( $err, @res ) = getaddrinfo( "www.google.com", "www", \%hints );

 die "Cannot resolve name - $err" if $err;

 while( my $ai = shift @res ) {

    $sock = IO::Socket->new();
    $sock->socket( $ai->{family}, $ai->{socktype}, $ai->{protocol} ) or
       undef $sock, next;

    $sock->connect( $ai->{addr} ) or undef $sock, next;

    last;
 }

 if( $sock ) {
    my ( $err, $host, $service ) = getnameinfo( $sock->peername );
    print "Connected to $host:$service\n" if !$err;
 }

=head1 DESCRIPTION

The RFC 2553 functions C<getaddrinfo> and C<getnameinfo> provide an abstracted
way to convert between a pair of host name/service name and socket addresses,
or vice versa. C<getaddrinfo> converts names into a set of arguments to pass
to the C<socket()> and C<connect()> syscalls, and C<getnameinfo> converts a
socket address back into its host name/service name pair.

These functions provide a useful interface for performing either of these name
resolution operation, without having to deal with IPv4/IPv6 transparency, or
whether the underlying host can support IPv6 at all, or other such issues.
However, not all platforms can support the underlying calls at the C layer,
which means a dilema for authors wishing to write forward-compatible code.
Either to support these functions, and cause the code not to work on older
platforms, or stick to the older "legacy" resolvers such as
C<gethostbyname()>, which means the code becomes more portable.

This module attempts to solve this problem, by detecting at compiletime
whether the underlying OS will support these functions. If it does not, the
module will use pure-perl emulations of the functions using the legacy
resolver functions instead. The emulations support the same interface as the
real functions, and behave as close as is resonably possible to emulate using
the legacy resolvers. See L<Socket::GetAddrInfo::Emul> for details on the
limits of this emulation.

As of C<Socket> version 1.93 (as shipped by Perl version 5.13.9, and hopefully
will be in 5.14), core Perl already supports C<getaddrinfo>. On such a system,
this module simply uses the functions provided by C<Socket>, and does not need
to use its own compiled XS, or pure-perl legacy emulation.

=cut

=head1 EXPORT TAGS

The following tags may be imported by C<use Socket::GetAddrInfo qw( :tag )>:

=over 8

=item AI

Imports all of the C<AI_*> constants for C<getaddrinfo> flags

=item NI

Imports all of the C<NI_*> constants for C<getnameinfo> flags

=item EAI

Imports all of the C<EAI_*> for error values

=item constants

Imports all of the above constants

=back

=cut

$EXPORT_TAGS{AI}  = [ grep m/^AI_/,  @EXPORT ];
$EXPORT_TAGS{NI}  = [ grep m/^NI_/,  @EXPORT ];
$EXPORT_TAGS{EAI} = [ grep m/^EAI_/, @EXPORT ];

$EXPORT_TAGS{constants} = [ map @{$EXPORT_TAGS{$_}}, qw( AI NI EAI ) ];

sub import
{
   my $class = shift;
   my %symbols = map { $_ => 1 } @_;

   my $api = "new";
   delete $symbols{':newapi'}; # legacy
   $api = "Socket6" if delete $symbols{':Socket6api'};

   if( $api eq "Socket6" and
       $symbols{getaddrinfo} || $symbols{getnameinfo} ) {

      my $callerpkg = caller;
      require Socket::GetAddrInfo::Socket6api;

      no strict 'refs';
      *{"${callerpkg}::getaddrinfo"} = \&Socket::GetAddrInfo::Socket6api::getaddrinfo if delete $symbols{getaddrinfo};
      *{"${callerpkg}::getnameinfo"} = \&Socket::GetAddrInfo::Socket6api::getnameinfo if delete $symbols{getnameinfo};
   }

   return unless keys %symbols;

   local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
   Exporter::import( $class, keys %symbols );
}

=head1 FUNCTIONS

=cut

=head2 ( $err, @res ) = getaddrinfo( $host, $service, $hints )

When given both host and service, this function attempts to resolve the host
name to a set of network addresses, and the service name into a protocol and
port number, and then returns a list of address structures suitable to
connect() to it.

When given just a host name, this function attempts to resolve it to a set of
network addresses, and then returns a list of these addresses in the returned
structures.

When given just a service name, this function attempts to resolve it to a
protocol and port number, and then returns a list of address structures that
represent it suitable to bind() to.

When given neither name, it generates an error.

The optional C<$hints> parameter can be passed a HASH reference to indicate
how the results are generated. It may contain any of the following four
fields:

=over 8

=item flags => INT

A bitfield containing C<AI_*> constants

=item family => INT

Restrict to only generating addresses in this address family

=item socktype => INT

Restrict to only generating addresses of this socket type

=item protocol => INT

Restrict to only generating addresses for this protocol

=back

Errors are indicated by the C<$err> value returned; which will be non-zero in
numeric context, and contain a string error message as a string. The value can
be compared against any of the C<EAI_*> constants to determine what the error
is.

If no error occurs, C<@res> will contain HASH references, each representing
one address. It will contain the following five fields:

=over 8

=item family => INT

The address family (e.g. AF_INET)

=item socktype => INT

The socket type (e.g. SOCK_STREAM)

=item protocol => INT

The protocol (e.g. IPPROTO_TCP)

=item addr => STRING

The address in a packed string (such as would be returned by pack_sockaddr_in)

=item canonname => STRING

The canonical name for the host if the C<AI_CANONNAME> flag was provided, or
C<undef> otherwise. This field will only be present on the first returned
address.

=back

=head2 ( $err, $host, $service ) = getnameinfo( $addr, $flags )

This function attempts to resolve the given socket address into a pair of host
and service names.

The optional C<$flags> parameter is a bitfield containing C<NI_*> constants.

Errors are indicated by the C<$err> value returned; which will be non-zero in
numeric context, and contain a string error message as a string. The value can
be compared against any of the C<EAI_*> constants to determine what the error
is.

=cut

=head1 BUILDING WITHOUT XS CODE

In some environments it may be preferred not to build the XS implementation,
leaving a choice only of the core or pure-perl emulation implementations.

 $ PERL_SOCKET_GETADDRINFO_NO_BUILD_XS=1 perl Build.PL 

=head1 BUGS

=over 4

=item *

Appears to FAIL on older Darwin machines (e.g. C<osvers=8.11.1>). The failure
mode occurs in F<t/02getnameinfo.t> and appears to relate to an endian bug;
expecting to receive C<80> and instead receiving C<20480> (which is a 16-bit
C<80> byte-swapped).

=back

=head1 SEE ALSO

=over 4

=item *

L<http://tools.ietf.org/html/rfc2553> - Basic Socket Interface Extensions for
IPv6

=back

=head1 ACKNOWLEDGEMENTS

Christian Hansen <chansen@cpan.org> - for help with some XS features and Win32
build fixes.

Zefram <zefram@fysh.org> - for help with fixing some bugs in the XS code.

Reini Urban <rurban@cpan.org> - for help with older perls and more Win32
build fixes.

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
