#!/usr/bin/perl
# DESC: script to demonstrate and test file locking
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: file-locking-demo.pl,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

use Fcntl qw(:flock);
$file = 'test.dat';

# open the file
open (FILE, ">>", "$file") || die "problem opening $file\n";

# immediately lock the file
print "try to lock $file \n";
flock FILE, LOCK_EX;
print "file $file is now locked\n";

# intentionally keep the lock on the file for ~20 seconds
$count = 0;
while ($count++ < 20)
{
  print FILE "count = $count\n";
  print "write count = $count into $file \n";
  sleep 1;
}

# close the file, which also removes the lock
close (FILE);

################################################################################
# $Log: file-locking-demo.pl,v $
# Revision 1.2  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:12  chris
# Initial revision
#
