#!/bin/bash
# DESC: mailtester via tls and smtp-auth
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Define the variables
SMTP_SERVER=relay.domain.tld
SMTP_USER=username
SMTP_PASS=secret
MAIL_FROM=from@domain.tld
MAIL_TO=to@domain.tld
MAIL_SUBJECT="Mail Subject Test"
MAIL_BODY="example text from Support"

# Send the email using swaks
swaks \
  --server $SMTP_SERVER \
  --port 587 \
  --auth LOGIN \
  --auth-user $SMTP_USER \
  --auth-password $SMTP_PASS \
  --from $MAIL_FROM \
  --to $MAIL_TO \
  --header "Subject: $MAIL_SUBJECT" \
  --body "$MAIL_BODY" \
  --tls

