#!/usr/bin/perl
# DESC: simple port scanner in perl
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: port-checker.pl,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

use strict;
use Socket;

# set time until connection attempt times out
my $timeout = 3;

if ($#ARGV != 1) {
  print "usage: port-check.pl hostname portnumber\n       OPEN=0 CLOSE=1 \n";
  exit 2;
}

my $hostname = $ARGV[0];
my $portnumber = $ARGV[1];
my $host = shift || $hostname;
my $port = shift || $portnumber;
my $proto = getprotobyname('tcp');
my $iaddr = inet_aton($host);
my $paddr = sockaddr_in($port, $iaddr);

socket(SOCKET, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";

eval {
  local $SIG{ALRM} = sub { die "timeout" };
  alarm($timeout);
  connect(SOCKET, $paddr) || error();
  alarm(0);
};

if ($@) {
  close SOCKET || die "close: $!";
  print "1\n";

  exit 1;
}
else {
  close SOCKET || die "close: $!";
  print "0\n";
  exit 0;
}

################################################################################
# $Log: port-checker.pl,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:17  chris
# Initial revision
#
