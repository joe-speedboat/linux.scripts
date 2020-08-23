#!/usr/bin/env perl

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Forked from original zabbix project and modified to match my needs
# Tested with CentOS 8.2 Core

# Option: SNMPTrapperFile
$SNMPTrapperFile = '/tmp/zabbix_traps.tmp';

# Option: DateTimeFormat
$DateTimeFormat = '%H:%M:%S %Y/%m/%d';

###################################
#### ZABBIX SNMP TRAP RECEIVER ####
###################################

use Fcntl qw(O_WRONLY O_APPEND O_CREAT);
use POSIX qw(strftime);
use NetSNMP::TrapReceiver;

sub zabbix_receiver
{
	my (%pdu_info) = %{$_[0]};
	my (@varbinds) = @{$_[1]};

	# open the output file
	unless (sysopen(OUTPUT_FILE, $SNMPTrapperFile, O_WRONLY|O_APPEND|O_CREAT, 0666))
	{
		print STDERR "Cannot open [$SNMPTrapperFile]: $!\n";
		return NETSNMPTRAPD_HANDLER_FAIL;
	}

	# get the host name
	my $hostname = $pdu_info{'receivedfrom'} || 'unknown';
	if ($hostname ne 'unknown')
	{
		$hostname =~ /\[(.*?)\].*/;                    # format: "UDP: [127.0.0.1]:41070->[127.0.0.1]"
		$hostname = $1 || 'unknown';
	}

	# print trap header
	#       timestamp must be placed at the beginning of the first line (can be omitted)
	#       the first line must include the header "ZBXTRAP [IP/DNS address] "
	#              * IP/DNS address is the used to find the corresponding SNMP trap items
	#              * this header will be cut during processing (will not appear in the item value)
	printf OUTPUT_FILE "%s ZBXTRAP %s\n", strftime($DateTimeFormat, localtime), $hostname;

	foreach my $x (@varbinds)
	{
	       if ( $x->[0] !~ m/SNMP-COMMUNITY-MIB::snmpTrapCommunity/ )
		{
			# printf OUTPUT_FILE "  %-30s type=%-2d value=%s\n", $x->[0], $x->[2], $x->[1];
			printf OUTPUT_FILE " $x->[1] ";
		}
	}
	printf OUTPUT_FILE "\n";

	close (OUTPUT_FILE);

	return NETSNMPTRAPD_HANDLER_OK;
}

NetSNMP::TrapReceiver::register("all", \&zabbix_receiver) or
	die "failed to register Zabbix SNMP trap receiver\n";

print STDOUT "Loaded Zabbix SNMP trap receiver\n";
