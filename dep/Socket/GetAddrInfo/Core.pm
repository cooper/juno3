#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2011 -- leonerd@leonerd.org.uk

package Socket::GetAddrInfo::Core;

use strict;
use warnings;

our $VERSION = '0.21';

# Load the actual code into Socket::GetAddrInfo
package # hide from indexer
  Socket::GetAddrInfo;

BEGIN { die '$Socket::GetAddrInfo::NO_CORE is set' if our $NO_CORE }

use Socket 1.93;

our @EXPORT = qw(
   getaddrinfo
   getnameinfo
);

push @EXPORT, grep { m/^AI_|^NI_|^EAI_/ } @Socket::EXPORT_OK;

Socket->import( @EXPORT );

0x55AA;
