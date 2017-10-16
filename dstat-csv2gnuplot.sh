#!/bin/bash
# DESC: create a html statistic with pictures from dstat csv export like: dstat -M cpu,load,sys,net,disk,page--output dstat.csv
# NOTE: it finds the name and values from dstat report, just start it
# USAGE: dstat-csv2gnuplot.sh dstat.csv
# $Author: chris $
# $Revision: 1.4 $
# $RCSfile: dstat-csv2gnuplot.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

INFILE=$1
XRES=1000
XLABEL="seconds"
YRES=250
YLABEL="ylabel"
INFILE_BASE=$(echo $INFILE | rev | cut -d. -f2- |rev)
OUTDIR=$INFILE_BASE-html
OUT_PLOT="$INFILE_BASE.gp"
OUT_DATA="$INFILE_BASE.dat"
OUT_HTML="$INFILE_BASE.html"
HTML_TITLE="DSTAT_GNUPLOT_DIAGRAM"
HOST=$(sed '3!d;s/.*Host:","//;s/",.*//;s/"//' $INFILE)
CMDLINE=$(sed '4!d;s/.*Cmdline:","//;s/",.*//' $INFILE)
DATE=$(sed '4!d;s/.*Date:","//;s/",.*//;s/"//' $INFILE)
COLUMN_CUR=1
TITLE_CUR=1

mkdir -p $OUTDIR
rm -f $OUTDIR/*
sed '1,7d' $INFILE | sed '=' | sed 'N;s/\n/,/' > "$OUTDIR/$OUT_DATA"

for TITLE in $(sed '6!d;s/ /_/g;s#/#_#g;s/"//g;s/,\([a-zA-Z0-9]\)/, \1/g;s/$/,/' $INFILE )
do
   #TITLE='tcp_sockets,,,,'
   COLUMN_SUB_TOTAL=$(echo $TITLE | grep -o , | wc -l)
   TITLE_FILE="$(echo $TITLE | sed 's/,//g')"
   TITLE_DISPLAY="$(echo $TITLE_FILE | sed 's/_/ /g')"

   echo "set terminal png size $XRES,$YRES"              >> "$OUTDIR/$OUT_PLOT"
   echo "set output \"${TITLE_CUR}_$TITLE_FILE.png\""    >> "$OUTDIR/$OUT_PLOT"
   echo "set title \"$TITLE_DISPLAY\""                   >> "$OUTDIR/$OUT_PLOT"
   echo "set xlabel \"$XLABEL\""                         >> "$OUTDIR/$OUT_PLOT"
   echo "#set ylabel \"$YLABEL\""                        >> "$OUTDIR/$OUT_PLOT"
   echo "set autoscale"                                  >> "$OUTDIR/$OUT_PLOT"
   echo "set grid"                                       >> "$OUTDIR/$OUT_PLOT"
   echo "set datafile separator \",\""                   >> "$OUTDIR/$OUT_PLOT"

   COLUMN_SUB_CUR=1
   for NR in $(seq $COLUMN_SUB_TOTAL)
   do
      VAL=$(sed '7!d;s/ /_/g;s#/#_#g;s/"//g' $INFILE | cut -d, -f$COLUMN_CUR) 
      if [ $COLUMN_SUB_CUR -eq 1 ]
      then
         echo -n "plot \"$OUT_DATA\" using 1:$(($COLUMN_CUR+1)) with lines title \"$VAL\", " >> "$OUTDIR/$OUT_PLOT"
      elif [ $COLUMN_SUB_CUR -lt $COLUMN_SUB_TOTAL ]
      then
         echo -n "'' using 1:$(($COLUMN_CUR+1)) with lines title \"$VAL\" , "                >> "$OUTDIR/$OUT_PLOT"
      elif [ $COLUMN_SUB_CUR -eq $COLUMN_SUB_TOTAL ]
      then
         echo "'' using 1:$(($COLUMN_CUR+1)) with lines title \"$VAL\" "                     >> "$OUTDIR/$OUT_PLOT"
      fi
      COLUMN_CUR=$(($COLUMN_CUR+1))
      COLUMN_SUB_CUR=$(($COLUMN_SUB_CUR+1))
   done
   echo >> "$OUTDIR/$OUT_PLOT"
   TITLE_CUR=$(($TITLE_CUR+1))
done

cd $OUTDIR
gnuplot "$OUT_PLOT"

echo "<html><TITLE>$HTML_TITLE</TITLE><BODY><CENTER>Hostname: $HOST<br>Date: $DATE<br>Cmd Line: $CMDLINE</CENTER>" > "$OUT_HTML"

for PNG in *.png
do
   echo "<hr><center><img src=\"$PNG\" alt=\"$PNG\"></center>" >> "$OUT_HTML"
done
echo "</BODY></HTML>" >> "$OUT_HTML"

################################################################################
# $Log: dstat-csv2gnuplot.sh,v $
# Revision 1.4  2012/06/10 19:18:52  chris
# auto backup
#
# Revision 1.3  2010/05/31 07:21:01  chris
# bugfix, did not plot last col in diagram
#
# Revision 1.1  2010/05/30 20:17:55  chris
# Initial revision
#

