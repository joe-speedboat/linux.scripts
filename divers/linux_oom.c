/**
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt
# INSPIRED BY: https://pubs.vmware.com/vsphere-6-5/index.jsp?topic=%2Fcom.vmware.vsphere.vcsapg-rest.doc%2FGUID-222400F3-678E-4028-874F-1F83036D2E85.html 

DESC: oom.c - allocate chunks of 10MB of memory indefinitely until you run out of memory

INSTALL:
   gcc -o linux_oom linux_oom.c
   chmod +x linux_oom
   ./linux_oom
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define TEN_MB 10 * 1024 * 1024

int main(int argc, char **argv){
        int c = 0;
        while (1){
                char *b = malloc(TEN_MB);
                memset(b, TEN_MB, 0);
                printf("Allocated %d MB\n", (++c * 10));
        }
        return 0;
}
