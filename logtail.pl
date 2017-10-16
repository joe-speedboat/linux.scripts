#!/usr/bin/perl
# DESC: logtail rewrite in perl, prints log lines that have been added since last logtail
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: logtail.pl,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

use strict;
use warnings;
my ($size, $logfile, $offsetfile);
use Getopt::Std;
my %opts = ();

# process args and switches
my ($TEST_MODE) = 0;
getopts("f:o:t", \%opts);

# try to detect plain logtail invocation without switches
if (!$opts{f} && $#ARGV != 0 && $#ARGV != 1) {
   print STDERR "No logfile to read. Use -f [LOGFILE].\n";
   exit 66;
} elsif ($#ARGV == 0) {
   $logfile = $ARGV[0];
} elsif ($#ARGV == 1) {
   ($logfile, $offsetfile) = ($ARGV[0], $ARGV[1]);
} else {
   ($logfile, $offsetfile) = ($opts{f}, $opts{o});
}

if ($opts{t}) {
    $TEST_MODE = 1;
}


if (! -f $logfile) {
    print STDERR "File $logfile cannot be read.\n";
    exit 66;
}
unless ($offsetfile) {
    # offsetfile not given, use .offset/$logfile in the same directory
    $offsetfile = $logfile . '.offset';
}

unless (open(LOGFILE, $logfile)) {
    print STDERR "File $logfile cannot be read.\n";
    exit 66;
}

my ($inode, $ino, $offset) = (0, 0, 0);

unless (not $offsetfile) {
    if (open(OFFSET, $offsetfile)) {
        $_ = <OFFSET>;
        unless (! defined $_) {
            chomp $_;
            $inode = $_;
            $_ = <OFFSET>;
            unless (! defined $_) {
                chomp $_;
                $offset = $_;
            }
        }
    }

    unless ((undef,$ino,undef,undef,undef,undef,undef,$size) = stat $logfile) {
        print STDERR "Cannot get $logfile file size.\n", $logfile;
        exit 65;
    }

    if ($inode == $ino) {
        exit 0 if $offset == $size; # short cut
        if ($offset > $size) {
            $offset = 0;
            print STDERR "***************\n";
            print STDERR "*** WARNING ***: Log file $logfile is smaller than last time checked!\n";
            print STDERR "***************\n";
        }
    }
    if ($inode != $ino || $offset > $size) {
        $offset = 0;
    }
    seek(LOGFILE, $offset, 0);
}

while (<LOGFILE>) {
    print $_;
}

$size = tell LOGFILE;
close LOGFILE;

# update offset, unless test mode
unless ($TEST_MODE) {
    unless (open(OFFSET, ">$offsetfile")) {
        print STDERR "File $offsetfile cannot be created. Check your permissions.\n";
        exit 73;
    }
    print OFFSET "$ino\n$size\n";
    close OFFSET;
}
exit 0;

# $Log: logtail.pl,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/03/04 07:10:07  chris
# Initial revision
#
