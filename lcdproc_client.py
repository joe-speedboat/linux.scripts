#! /usr/bin/python
# DESC: display simple text messages via lcdproc, written for Matrix Orbital LK204-25
# $Revision: 1.6 $
# $RCSfile: lcdproc_client.py,v $
# $Author: chris $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

import sys
import os
import socket
import re
import time
from optparse import OptionParser

usage = "usage: %prog [options] -f <MSG_FILE>"
parser = OptionParser(usage=usage, description="")
parser.add_option("-f", dest="msg_file", help="file to display on lcd screen, - to read stdin")
parser.add_option("-b", action="store_true", dest="blink", help="blink display backlight while showing message", default=False)
parser.add_option("-t", dest="msg_time", help="time in seconds to show message, default is 5 seconds", default=5)
parser.add_option("-s", dest="host", help="lcdproc server, default is localhost", default='localhost')
parser.add_option("-p", dest="host_port", help="lcdproc server port, default is 13666", default=13666)
parser.add_option("-v", action="store_true", dest="verbose", help="verbose output", default=False)

(options, terms) = parser.parse_args()

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
screen = ('lcd' + str(os.getpgid(0)))

if not options.msg_file:
    print parser.print_help()
    parser.exit()

if options.msg_file == '-':
   msg_text = sys.stdin.readlines()
else:
   file = open(options.msg_file,'r')
   msg_text = file.readlines()
   file.close()

def verbose(msg_verbose):
   if options.verbose:
      print "=> " + str(msg_verbose)

def lcd_open():
   s.connect((options.host, options.host_port))
   lcdproc_version = lcd_cmd('hello')
   lcd_hgt = int(re.sub(' .*', '', re.sub('.* hgt ', '', lcdproc_version)))
   lcd_cmd('client_set name usb')
   lcd_cmd('screen_add ' + screen)
   return(lcd_hgt)

def lcd_close():
   lcd_cmd('screen_set ' + screen + ' backlight off')
   s.close()

def lcd_cmd(lcdproc_cmd):
   s.send(lcdproc_cmd + '\n')
   verbose('lcdproc_cmd: ' + lcdproc_cmd)
   lcdproc_out = s.recv(1024).strip('\n')
   lcdproc_out = lcdproc_out.strip('\n')
   verbose('lcdproc_out: ' + str(lcdproc_out))
   return(lcdproc_out)

def main():
   verbose('all cmd opts: ' + str(options))
   verbose('msg_text: ' + str(msg_text))
   lcd_hgt = lcd_open()
   verbose('lcd_hgt: ' + str(lcd_hgt))
   while msg_text:
      for lcd_line_nr in range(lcd_hgt):
         if len(msg_text) == 0:
            msg_line = ''
         else:
            msg_line = msg_text.pop(0)
         msg_line = msg_line.strip('\n')
         if options.blink:
            lcd_cmd('screen_set ' + screen + ' backlight blink')
         lcd_cmd('widget_add ' + screen + ' lcd_page' + str(lcd_line_nr) + ' string')
         lcd_cmd('widget_set ' + screen + ' lcd_page' + str(lcd_line_nr) + ' 1 ' + str(lcd_line_nr + 1) + ' "' + msg_line + '"')
      verbose('sleeping ' + str(options.msg_time) + ' seconds')
      time.sleep(int(options.msg_time))
      lcd_cmd('widget_del ' + screen + ' lcd_page' + str(lcd_line_nr))
   lcd_close()

if __name__ == "__main__":
   try:
      main()
   except KeyboardInterrupt:
      pass
 
################################################################################
# $Log: lcdproc_client.py,v $
# Revision 1.6  2010/07/08 12:43:30  chris
# bugfix, option -f is now mandatory
#
# Revision 1.5  2010/07/08 08:09:48  chris
# bugfix to work also with single line of text
#
# Revision 1.1  2010/07/05 18:36:20  chris
# Initial revision
#
