#!/bin/bash
# DESC: simple exams for my students

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# rm -f exam ; shc -v -r -f exam.sh ; rm -f exam.sh.x.c ; mv exam.sh.x exam ; git add exam ; git commit -a -m release ; git push

#---------- GLOBAL VARS --------------------------------------------------
export LANG="en_US.UTF-8"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TOP_PID=$$

#---------- MY VARS --------------------------------------------------
DEBUG=0
DOWARN=1

#---------- INTERNAL VARS ----------------------------------------------
DATE="$(date '+%Y.%m.%d_%H.%M.%S')"
DATE_PATTERN='[0-9]{4}\.[0-9]{2}\.[0-9]{2}\_[0-9]{2}\.[0-9]{2}\.[0-9]{2}'

RESULT_FILE=/etc/sysconfig/.results.log
RESULT_URL="https://share.bitbull.ch/public.php/webdav/"
RESULT_USER=FkeyG6CZfDGm5Aq
RESULT_PW=Kp5zbfab

#---------- FUNCTIONS --------------------------------------------------
# log handling
log(){ #---------------------------------------------------
   LEVEL=$(echo $1 | tr 'a-z' 'A-Z' ) ; shift
   if [ "$LEVEL" = "DEBUG" -a $DEBUG -eq 1 ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" | tee -a $RESULT_FILE
   fi
   if [ "$LEVEL" = "ERROR" -o "$LEVEL" = "WARNING" -o "$LEVEL" = "INFO" ] ; then
      echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0):$LEVEL: $*" | tee -a $RESULT_FILE
   fi
   if [ "$LEVEL" = "ERROR" ]
   then
      kill $TOP_PID
      kill -9 $TOP_PID
   fi
}

# give help
dohelp(){ #------------------------------------------------
   echo "
   Version: 1.13
   Usage: $(basename $0)
           disk1   start    Starte Aufgabe zum Disk System
           disk1   grade    Pruefe Loesung zur Aufgabe

           disk2   start    Starte Aufgabe zum Disk System
           disk2   grade    Pruefe Loesung zur Aufgabe

           soft1   start    Starte Software Aufgabe
           soft1   grade    Pruefe Loesung zur Aufgabe

           soft2   start    Starte Software Aufgabe
           soft2   grade    Pruefe Loesung zur Aufgabe

           soft3   start    Starte Software Aufgabe
           soft3   grade    Pruefe Loesung zur Aufgabe

           perm1   start    Starte Permission Aufgabe (optional)
           perm1   grade    Pruefe Loesung zur Aufgabe

           svc1    start    Starte Service Aufgabe
           svc1    grade    Pruefe Loesung zur Aufgabe

           svc2    start    Starte Service Aufgabe
           svc2    grade    Pruefe Loesung zur Aufgabe

           adm1    start    Starte Admin Aufgabe
           adm1    grade    Pruefe Loesung zur Aufgabe

           adv1    start    Starte Bonus Aufgabe (optional)
           adv1    grade    Pruefe Bonus zur Aufgabe

           sync             Uebermittle die Resultate der Uebungen

           -h|--help        Zeige diese Hilfe

   Beispiel: $(basename $0) disk1 grade

   "
exit 0
}

# check if all progs are installed
for PROG in dd curl
do
   which $PROG >/dev/null 2>&1 || log error $PROG does not exist, please install first
done

id | grep -q root || log error you need to run this as root

. /etc/os-release
echo $ID_LIKE | grep -q rhel || log error This script was written for CentOS8 or RHEL8 other OS are not supported


# send warning for dangerous tasks if wanted
dowarn(){ #------------------------------------------------
   if [ $DOWARN -eq 1 ]
   then
      echo "   -=WARNING=-"
      echo "   YOU ARE ABOUT TO CHANGE SOMETHING"
      echo "   press 3x<ENTER> to continume or <CTRL>-<C> to abort"
      read x ; read x ; read x
      echo "okay, dann mal los.... 
      bitte warten, das System boootet nach der installation der Uebung"
   fi
}

disk1_start(){ #----------------------------------------------
   log info "Exercise: Disk1 started"
   echo
   echo "Irgend etwas mit dem Dateisystem stimmt nicht, finde den fehler und behebe diesen"
   echo
   dowarn
   dd if=/dev/zero of=/var/log/bigfile.log bs=1M >/dev/null 2>&1
   sync ; sync ; sync
   reboot -f
}
disk1_grade(){ #----------------------------------------------
   log info "Grading: Disk1 started"
   echo GRADING ... ; sleep 3
   VAL=$(df /var/log | grep /dev/ | awk '{print $5}' | cut -d'%' -f1)
   if [ $VAL -lt 90 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
disk2_start(){ #----------------------------------------------
   log info "Exercise: Disk2 started"
   echo
   echo "Irgend etwas mit dem Dateisystem stimmt nicht, finde den fehler und behebe diesen"
   echo
   dowarn
   dd if=/dev/zero of=/tmp/.dump bs=1M >/dev/null 2>&1
   sync ; sync ; sync
   reboot -f
}
disk2_grade(){ #----------------------------------------------
   log info "Grading: Disk2 started"
   echo GRADING ... ; sleep 3
   VAL=$(df /tmp | grep /dev/ | awk '{print $5}' | cut -d'%' -f1)
   if [ $VAL -lt 90 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
soft1_start(){ #----------------------------------------------
   log info "Exercise: Soft1 started"
   echo
   echo "Aktualisiere alle Software Pakete des Systems"
   echo
}
soft1_grade(){ #----------------------------------------------
   log info "Grading: Soft1 started"
   echo GRADING ... ; sleep 3
   dnf makecache >/dev/null 2>&1 
   sleep 5
   VAL=$(echo N | dnf list --upgrades | wc -l)
   if [ $VAL -lt 2 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
soft2_start(){ #----------------------------------------------
   log info "Exercise: Soft2 started"
   echo
   echo "Das Program host soll ausfuehrbar sein, installiere die notwendige Software"
   echo
}
soft2_grade(){ #----------------------------------------------
   log info "Grading: Soft2 started"
   echo GRADING ... ; sleep 3
   VAL=$(which host 2>/dev/null | egrep '^/' | wc -l)
   if [ $VAL -eq 1 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
soft3_start(){ #----------------------------------------------
   log info "Exercise: Soft3 started"
   echo
   echo "Der folgende Befehl soll erfolgreich ausgefuehrt werden koennen:"
   echo "   nc -z -v 127.0.0.1 22"
   echo
}
soft3_grade(){ #----------------------------------------------
   log info "Grading: Soft3 started"
   echo GRADING ... ; sleep 3
   VAL=$(nc -z -v 127.0.0.1 22 2>&1 | egrep 'Connected to 127.0.0.1' | wc -l)
   if [ $VAL -eq 1 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
perm1_start(){ #----------------------------------------------
   log info "Exercise: Perm1 started"
   echo
   echo "Erstelle folgende Gruppen:"
   echo "   family"
   echo "   parents"
   echo
   echo "Erstelle folgende User:"
   echo "   mimi"
   echo "   timi"
   echo "   joe"
   echo "   jane"
   echo
   echo "Alle User sollen der Gruppe family angehören"
   echo "joe und jane sollen der Gruppe parents angehören"
   echo
   echo "Erstelle die Verzeichnisse:"
   echo "   /srv/nfs/family/all"
   echo "   /srv/nfs/family/parents"
   echo
   echo "Neu erstellte Dateien/Verzeichnisse unter /srv/nfs/family/all sollen der Gruppe family gehören, diese sollen schreibrechte erhalten"
   echo "Neu erstellte Dateien/Verzeichnisse unter /srv/nfs/family/parents sollen der Gruppe parents gehören, ausschliesslich die Gruppe parents soll schreibrechte erhalten"
   echo "User welche nicht Mitglied der Gruppe family sind sollen auf /srv/nfs/family nicht zugreifen können"
   echo
   echo "Für diese Aufgabe verwendest Du folgende Befehle:"
   echo "   groupadd"
   echo "   useradd"
   echo "   usermod"
   echo "   mkdir"
   echo "   chown"
   echo "   chmod"
   echo "Und optional:"
   echo "   man"
   echo "   su"
   echo "   ls"
}
perm1_grade(){ #----------------------------------------------
   log info "Grading: Perm1 started"
   echo GRADING ... ; sleep 1
   echo
   echo "Teste User mimi"  | tee -a $RESULT_FILE
   sleep 1
   ( id mimi 2>&1 | grep -q family && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste User timi" | tee -a $RESULT_FILE
   sleep 1
   ( id timi 2>&1 | grep -q family && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste User joe" | tee -a $RESULT_FILE
   sleep 1
   ( id joe 2>&1 | grep parents | grep -q family && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste User jane" | tee -a $RESULT_FILE
   sleep 1
   ( id jane 2>&1 | grep parents | grep -q family && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE

   echo "Teste Rechte auf /srv/nfs/family" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family -d 2>&1 | grep -q drwxrwx--- && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste Gruppen Eigentümer auf /srv/nfs/family" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family -d 2>&1 | grep -q " family " && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE

   echo "Teste Rechte auf /srv/nfs/family/all" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family/all -d 2>&1 | grep -q drwxrws--- && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste Gruppen Eigentümer auf /srv/nfs/family/all" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family/all -d 2>&1 | grep -q " family " && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   
   echo "Teste Rechte auf /srv/nfs/family/parents" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family/parents -d 2>&1 | grep -q drwxrws--- && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE
   echo "Teste Gruppen Eigentümer auf /srv/nfs/family/parents" | tee -a $RESULT_FILE
   sleep 1
   ( ls -l /srv/nfs/family/parents -d 2>&1 | grep -q " parents " && echo "   OK" || echo "   FAIL" ) | tee -a $RESULT_FILE

}
svc1_start(){ #----------------------------------------------
   log info "Exercise: Svc1 started"
   echo
   echo "Ein Dienst hat ein Problem, finde und behebe dieses"
   echo
   dowarn
   dnf -y install chrony >/dev/null 2>&1
   systemctl enable chronyd
   echo "THIS SHOULD NOT BE HERE" >> /etc/chrony.conf
   sync ; sync ; sync
   reboot -f
}
svc1_grade(){ #----------------------------------------------
   log info "Grading: Svc1 started"
   echo GRADING ... ; sleep 3
   VAL=$(pgrep chronyd | wc -l)
   if [ $VAL -eq 1 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
svc2_start(){ #----------------------------------------------
   log info "Exercise: Svc2 started"
   echo
   echo "Konfiguriere den SNMP Dienst"
   echo 'Er soll auf der Adresse "127.0.0.1" auf den Comunity String "secret" antworten'
   echo
}
svc2_grade(){ #----------------------------------------------
   log info "Grading: Svc2 started"
   echo GRADING ... ; sleep 3
   VAL=$(snmpwalk -v2c -c secret -On -t15 127.0.0.1 .1 2>&1 | wc -l)
   if [ $VAL -gt 25 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
adm1_start(){ #----------------------------------------------
   log info "Exercise: Adm1 started"
   echo
   echo "Erstelle einen neuen User"
   echo 'Name: ladmin'
   echo 'Passwort: redhat'
   echo 'Rechte: sudo su -'
   echo 'Beschreibung: Dieser Befehl erlaubt es root Rechte zu erlangen'
   echo

}
adm1_grade(){ #----------------------------------------------
   log info "Grading: Adm1 started"
   echo GRADING ... ; sleep 3
   VAL=$(su ladmin -c "echo 'redhat'  | sudo -k -S id" 2>/dev/null| grep 'uid=0' | wc -l)
   if [ $VAL -eq 1 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
adv1_start(){ #----------------------------------------------
   log info "Exercise: Adv1 started"
   echo
   echo "Ein Lehrling war am Werk und seither bootet das system nicht mehr richtig"
   echo 'Der gute wollte einige Berechtigungen mit chmod anpassen'
   echo 'finde und behebe den fehler'
   echo
   dowarn
   chmod 000 /
   sync ; sync ; sync
   reboot -f

}
adv1_grade(){ #----------------------------------------------
   log info "Grading: Adv1 started"
   echo GRADING ... ; sleep 3
   VAL=$(ls -ld / | grep dr-xr-xr-x | wc -l)
   if [ $VAL -eq 1 ]
   then
      echo PASSED | tee -a $RESULT_FILE
   else
      echo FAILED | tee -a $RESULT_FILE
   fi
}
sync_results(){ #----------------------------------------------
   log info "Sync Results gestartet"
   echo -n "Bitte gib Deine eMail Adresse ein: "
   read email
   email="$(echo $email | tr '@' '_')"
   echo "EMAIL=$email" >> $RESULT_FILE
   test -f /tmp/results_$email.txt && rm -f /tmp/results_$email.txt
   cp -apf $RESULT_FILE /tmp/results_$email.txt
   curl -k -u $RESULT_USER:$RESULT_PW -H "X-Requested-With: XMLHttpRequest" "$RESULT_URL" -T /tmp/results_$email.txt && \
      log info Die Ergebnisse wurden uebertragen, vielen Dank || log warning Die Resultate konnten nicht uebertragen werden
   rm -f /tmp/results_$email.txt
}

# ---------- MAIN PROGRAM --------------------------------------------------
# ---------- PARSE ALL INPUT ARGUMENTS --------------------
ARG=$1
case $ARG in
   disk1)
      shift
      if [ "$1" == "start" ] 
      then
         disk1_start
      elif [ "$1" == "grade" ]
      then
         disk1_grade
      else
         dohelp
      fi
      ;;
   disk2)
      shift
      if [ "$1" == "start" ] 
      then
         disk2_start
      elif [ "$1" == "grade" ]
      then
         disk2_grade
      else
         dohelp
      fi
      ;;
   soft1)
      shift
      if [ "$1" == "start" ] 
      then
         soft1_start
      elif [ "$1" == "grade" ]
      then
         soft1_grade
      else
         dohelp
      fi
      ;;
   soft2)
      shift
      if [ "$1" == "start" ] 
      then
         soft2_start
      elif [ "$1" == "grade" ]
      then
         soft2_grade
      else
         dohelp
      fi
      ;;
   soft3)
      shift
      if [ "$1" == "start" ] 
      then
         soft3_start
      elif [ "$1" == "grade" ]
      then
         soft3_grade
      else
         dohelp
      fi
      ;;
   perm1)
      shift
      if [ "$1" == "start" ] 
      then
         perm1_start
      elif [ "$1" == "grade" ]
      then
         perm1_grade
      else
         dohelp
      fi
      ;;
   svc1)
      shift
      if [ "$1" == "start" ] 
      then
         svc1_start
      elif [ "$1" == "grade" ]
      then
         svc1_grade
      else
         dohelp
      fi
      ;;
   svc2)
      shift
      if [ "$1" == "start" ] 
      then
         svc2_start
      elif [ "$1" == "grade" ]
      then
         svc2_grade
      else
         dohelp
      fi
      ;;
   adm1)
      shift
      if [ "$1" == "start" ] 
      then
         adm1_start
      elif [ "$1" == "grade" ]
      then
         adm1_grade
      else
         dohelp
      fi
      ;;
   adv1)
      shift
      if [ "$1" == "start" ] 
      then
         adv1_start
      elif [ "$1" == "grade" ]
      then
         adv1_grade
      else
         dohelp
      fi
      ;;
   sync)
      sync_results
      ;;
   *)
      dohelp 
      ;;
esac



################################################################################
exit 0
#### perm1 ################################################
groupadd family
groupadd parents
useradd mimi
useradd timi
useradd joe
useradd jane
usermod -a -G family mimi
usermod -a -G family timi
usermod -a -G family joe
usermod -a -G family jane
usermod -a -G parents joe
usermod -a -G parents jane
mkdir -p /srv/nfs/family/all /srv/nfs/family/parents
chmod -R o-rwx,ug+rwX /srv/nfs/family
chown -R :family /srv/nfs/family
chown -R :parents /srv/nfs/family/parents
chmod g+s /srv/nfs/family/all /srv/nfs/family/parents

