#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

set -euo pipefail

DEFAULT_RATE="1/s"
LOG_RATE="5/s"   # Log-Drosselung (wichtig gegen Flood)

usage() {
    echo "Usage:"
    echo "  $0 -a <IP> <PORT> [RATE]"
    echo "  $0 -d <IP>"
    echo "  $0 -l"
    exit 1
}

# =========================
# RATE → BURST
# =========================
rate_to_burst() {
    local rate="$1"
    local value="${rate%%/*}"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "1"
        return
    fi

    echo "$value"
}

# =========================
# LIST
# =========================
list_rules() {
    echo "Current direct rules:"
    firewall-cmd --permanent --direct --get-all-rules
}

# =========================
# DELETE
# =========================
delete_ip() {
    IP="$1"

    [[ -z "$IP" ]] && usage

    RULES=$(firewall-cmd --permanent --direct --get-all-rules | grep "$IP" || true)

    if [[ -z "$RULES" ]]; then
        echo "ℹ️  No rules found"
        return 0
    fi

    while read -r rule; do
        [[ -z "$rule" ]] && continue

        family=$(echo "$rule" | awk '{print $1}')
        table=$(echo "$rule" | awk '{print $2}')
        chain=$(echo "$rule" | awk '{print $3}')
        priority=$(echo "$rule" | awk '{print $4}')
        args=$(echo "$rule" | cut -d' ' -f5-)

        firewall-cmd --permanent --direct --remove-rule "$family" "$table" "$chain" "$priority" $args
        echo "➖ removed: $rule"
    done <<< "$RULES"
}

# =========================
# ADD
# =========================
add_ip() {
    IP="$1"
    PORT="$2"
    RATE="${3:-$DEFAULT_RATE}"

    [[ -z "$IP" || -z "$PORT" ]] && usage

    BURST=$(rate_to_burst "$RATE")
    LOG_BURST=$(rate_to_burst "$LOG_RATE")

    echo "Setting rate limit for $IP:$PORT ($RATE, burst=$BURST)..."

    delete_ip "$IP"

    # -------------------------
    # 1. ACCEPT (unter Limit)
    # -------------------------
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 \
        -s "$IP" -p tcp --dport "$PORT" \
        -m conntrack --ctstate NEW \
        -m limit --limit "$RATE" --limit-burst "$BURST" \
        -j ACCEPT

    echo "➕ ACCEPT limit $RATE (burst=$BURST)"

    # -------------------------
    # 2. LOG (nur wenn NICHT accepted)
    # -------------------------
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 \
        -s "$IP" -p tcp --dport "$PORT" \
        -m conntrack --ctstate NEW \
        -m limit --limit "$LOG_RATE" --limit-burst "$LOG_BURST" \
        -j LOG --log-prefix "RL_DROP $IP:$PORT " --log-level 6

    echo "➕ LOG enabled (rate=$LOG_RATE)"

    # -------------------------
    # 3. DROP (hart)
    # -------------------------
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 2 \
        -s "$IP" -p tcp --dport "$PORT" \
        -m conntrack --ctstate NEW \
        -j DROP

    echo "➕ DROP fallback"
}

# =========================
# ARG PARSE
# =========================
case "${1:-}" in
    -a)
        add_ip "${2:-}" "${3:-}" "${4:-}"
        ;;
    -d)
        [[ -z "${2:-}" ]] && usage
        delete_ip "$2"
        ;;
    -l)
        list_rules
        exit 0
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "Reloading firewalld..."
firewall-cmd --reload

echo "Done."
