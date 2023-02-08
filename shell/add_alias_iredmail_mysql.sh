#!/bin/bash
# DESC: add alias email to iRedMail with MySQL backend

DEFAULT=domain.ch ; TEXT="domain" ; read -p "$TEXT ($DEFAULT): " VAL ; [ "x$VAL" = "x" ] && VAL=$DEFAULT ; DOM="$VAL"
DEFAULT=chris ; TEXT="Mail Account" ; read -p "$TEXT ($DEFAULT): " VAL ; [ "x$VAL" = "x" ] && VAL=$DEFAULT ; ACC="$VAL"
DEFAULT=sales ; TEXT="Mail Alias" ; read -p "$TEXT ($DEFAULT): " VAL ; [ "x$VAL" = "x" ] && VAL=$DEFAULT ; ALIAS="$VAL"


echo "INSERT INTO forwardings (address, forwarding,
                              domain, dest_domain,
                              is_alias, active)
                      VALUES ('$ALIAS@$DOM', '$ACC@$DOM',
                              '$DOM', '$DOM',
                              1, 1);" | mysql vmail
echo 'select * from forwardings;' | mysql -t vmail

