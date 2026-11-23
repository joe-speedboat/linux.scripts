#!/usr/bin/env bash
# DESC: Persistent manually started rootless Podman browser desktop.
# Copyright (c) 2026 Chris Ruettimann <chris@bitbull.ch>
# SPDX-License-Identifier: GPL-3.0-only
# No warranty. See LICENSE or https://www.gnu.org/licenses/gpl-3.0.html.
#
# OPERATOR GUIDE
# Rocky 9/10, AlmaLinux/RHEL 9; root administers the host, never runs Podman.
# Bash + jq + curl + coreutils/util-linux/iproute are required. install/update
# bootstrap jq/curl explicitly, then install HOST_PACKAGES using dnf. Help and
# dry-run never install anything. Saved schema-2 config is authoritative; edit
# config.json and run update. update rebuilds the IMAGE, not this script.
# Home and credentials survive all operations except reset deletes ONLY home.
# Reset also deletes profiles, SSH keys and the self-signed TLS certificate.
# Initial random password appears once after success, outside manager logs.
# If interrupted around initial output, root can inspect CREDS_FILE; exactly-once
# terminal delivery cannot be guaranteed across a crash. Credentials are retained.
# Credentials are parsed as data, never sourced. No password is passed in argv.
# Root-only metadata is 0600. BASE is 0711, runtime home 0700. A dedicated
# nologin user with managed GECOS/subids owns persistent rootless storage.
# Ancestor traversal uses named execute-only ACLs (root-only backups first).
# Masked ACLs are rejected rather than broadening existing permissions.
# ACLs/packages/user/linger persist across rollback and reset. Restore ACLs
# manually only after reviewing backups (setfacl --restore=FILE).
# Linger/user@UID.service are enabled; NO desktop boot service/restart policy.
# Rootless pasta publishes HTTPS 8443. Default firewall sources are RFC1918.
# --skip-firewall-config (install/update, before or after command) makes NO
# firewall queries/changes/removals, preserves rule ownership, and refuses
# recovery of a prior firewall-managed journal. Supply it each invocation.
# Normal mode requires active firewalld; existing unrelated rules are retained.
# SELinux stays enabled: :Z plus owned MountLabel relabel before stopped starts.
# No live relabel, privileged mode, host socket or disabled security isolation.
# Image builds precede stopping; original container retained until commit.
# Prepared/committed journals recover on the next modifying invocation.
# Metadata backups are NOT home backups; rollback cannot undo app migrations.
# Upstream Webtop Alpine XFCE provides Selkies HTTPS/Basic auth. Container sudo
# is upstream policy: this is a private single-user desktop, not multi-tenant.
# Additional Alpine packages are editable below. PRoot/AppImage catalog apps
# can still fail due to GPU/kernel restrictions (e.g. Ghostty/Bitwarden).
# Glycin adapter scopes /dev workaround to Glycin; no isolation is disabled.
# Use a VM for broad native application compatibility. No automatic updates.
set -Eeuo pipefail
set +x
shopt -s inherit_errexit
umask 077

# Edit defaults BEFORE first installation. Never change paths to migrate data.
DATA_DIR="/srv/docker/web-desktop"
CFG_FILE="${DATA_DIR}/config.json"
CREDS_FILE="${DATA_DIR}/credentials.env"
DEFAULT_USER=webdesktop
RUNTIME_USER=webdesktop
CONTAINER_NAME=web-desktop
BIND_ADDRESS=""
PORT=8443
ALLOWED_NETWORKS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)
UPSTREAM_IMAGE=lscr.io/linuxserver/webtop:alpine-xfce
HOST_PACKAGES=(podman passt acl)
DESKTOP_PACKAGES=(openssh-client)
GLYCIN_COMPAT=true
DESKTOP_UID=1000
DESKTOP_GID=1000
TIMEZONE=Europe/Zurich
DESKTOP_TITLE='Web Desktop'
MEMORY_LIMIT=2500m
SHM_SIZE=1g
PIDS_LIMIT=2048
READY_TIMEOUT=90
OWNER=io.local.web-desktop.managed
STATE_FILE=$DATA_DIR/state.json
JOURNAL_FILE=$DATA_DIR/transaction.json
DESKTOP_HOME=$DATA_DIR/home
RUNTIME_HOME=$DATA_DIR/runtime
VERSION=3.0
COMMAND='' SKIP=false DRY=false YES=false FOLLOW=false TAIL=100 EXPLICIT='' HELP=false
CONFIG='' STATE='' TRANSACTION='' RUID='' RGID='' CUSTOM_USER='' PASSWORD=''

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage_error() { printf 'Invalid option/command: %s\n' "$*" >&2; exit 2; }
help_text() {
    cat <<EOF
Web Desktop Manager $VERSION — rootless Podman, manually started.
Usage: web-desktop.sh COMMAND [OPTIONS]

  install [--bind-address IPv4] [--skip-firewall-config] [--dry-run]
      Install/start or resume/reuse the active deployment.
  update [--skip-firewall-config] [--dry-run]
      Rebuild image/apply saved settings; preserve home/password and run state.
  start                   Start/recreate active deployment, no image pull.
  stop                    Stop; retain home, password, image and firewall rules.
  reset [--yes]           DELETE home; retain password/image. No home backup.
  status                  Read-only active URL/image/config/recovery summary.
  logs [--tail N] [--follow]
      Read exact container journal as root; default tail 100 (0..100000).
  --help / COMMAND --help  Help; no changes or dependency installation.
  --version               Print version.

Options are command-scoped; --skip-firewall-config also works before COMMAND.
  --skip-firewall-config   No firewall queries, changes or removals. Pass each time.
  --dry-run               Read-only plan, no packages/builds/password generation.
  --bind-address IPv4     First install only; otherwise edit saved config.
  --yes                  Reset only: skip typing RESET at the terminal.

Examples:
  web-desktop.sh install --bind-address 192.0.2.10 --skip-firewall-config
  web-desktop.sh --skip-firewall-config update
  web-desktop.sh update --skip-firewall-config --dry-run
  web-desktop.sh logs --tail 50 --follow

Saved settings: $CFG_FILE
Persistent home: $DESKTOP_HOME
Edit saved config, then update. update does NOT self-update this script.
Default HTTPS port: $PORT; self-signed TLS. No desktop boot autostart.
Root host setup; all Podman commands run as a validated dedicated Linux user.
Supported: Rocky 9/10, AlmaLinux/RHEL 9. jq/curl prerequisites are bootstrapped
only on real install/update. Firewall configuration is ON unless skipped.
Skipped firewall access control is the operator's responsibility.
Full defaults, host side effects and app limitations: this script's header.
EOF
    case $COMMAND in
        install) printf '\nINSTALL: saved deployment is reused; edits require update. Initial password\nappears once after successful readiness. Host packages, user, subids, ACLs,\nlinger and persistent rootless storage are prepared. Address defaults to\nlocal default-route IPv4. No external packets are needed for address selection.\n' ;;
        update) printf '\nUPDATE: build before stop; retain original container until activation commits.\nFailure restores original container; interrupted journals recover next time.\nMetadata backups exclude home. Packages/app home migrations cannot roll back.\nSkip refuses pending firewall-managed journals; recover without skip first.\n' ;;
        reset) printf '\nRESET: permanently removes profiles, downloads, SSH keys and TLS certificate.\nNo undo. Requires RESET on /dev/tty or --yes. Symlinks/nested mounts refused.\n' ;;
        start|stop) printf '\nUses applied settings, not unapplied config edits. Home/password retained.\nNo desktop service is installed. Use start after reboot.\n' ;;
        status) printf '\nExit 3 means absent/incomplete. Does not recover journals or start services.\n' ;;
        logs) printf '\nApplication-generated logs may contain sensitive data. No lifecycle changes.\n' ;;
    esac
}
parse_cli() {
    local opt
    local -a options=()
    while (($#)); do
        opt=$1; shift
        case $opt in
            install|start|stop|update|reset|status|logs) [[ -z $COMMAND ]] || usage_error 'multiple commands'; COMMAND=$opt ;;
            --skip-firewall-config) SKIP=true; options+=(skip) ;;
            --dry-run) DRY=true; options+=(dry) ;;
            --yes) YES=true; options+=(yes) ;;
            --follow) FOLLOW=true; options+=(follow) ;;
            --tail|--bind-address)
                (($#)) || usage_error "$opt requires a value"
                if [[ $opt == --tail ]]; then TAIL=$1; options+=(tail); else EXPLICIT=$1; options+=(bind); fi; shift ;;
            --help|-h) HELP=true ;;
            --version) [[ $# == 0 && -z $COMMAND && $HELP == false && ${#options[@]} == 0 ]] || usage_error '--version alone'; printf '%s\n' "$VERSION"; exit 0 ;;
            *) usage_error "$opt" ;;
        esac
    done
    for opt in "${options[@]}"; do
        case $COMMAND:$opt in install:skip|update:skip|install:dry|update:dry|install:bind|reset:yes|logs:tail|logs:follow) ;; *) usage_error "$opt is not valid for $COMMAND" ;; esac
    done
    if [[ ! $TAIL =~ ^[0-9]{1,6}$ ]]; then usage_error '--tail must be 0..100000'; fi
    ((10#$TAIL <= 100000)) || usage_error '--tail must be 0..100000'
    if $HELP; then help_text; exit 0; fi
    [[ -n $COMMAND ]] || usage_error 'command required; use --help'
}
random_hex() { od -An -N24 -tx1 /dev/urandom | tr -d ' \n'; }
get() { jq -r "$1" <<<"${2:-$CONFIG}"; }
json_array() { printf '%s\n' "$@" | jq -Rsc 'split("\n") | map(select(length>0))'; }
atomic() {
    local path=$1 tmp
    [[ ! -L $path ]] || fail "Symlink: $path"
    tmp=$(mktemp "${path}.tmp.XXXXXXXX")
    cat >"$tmp"
    chmod "${2:-600}" "$tmp"
    sync -f "$tmp"
    mv -fT -- "$tmp" "$path"
    sync -f "${path%/*}"
}
secure_read() {
    [[ -f $1 && ! -L $1 && $(stat -c '%u:%a' "$1") == 0:600 ]] || fail "Expected root-owned regular 0600 file: $1"
    cat -- "$1"
}
check_paths() {
    local p mode
    [[ $DATA_DIR == /*/* && $DATA_DIR != */ && $DATA_DIR != *[$'\n\r\t ']* ]] || fail 'Unsafe DATA_DIR'
    [[ ${CFG_FILE%/*} == "$DATA_DIR" && ${CREDS_FILE%/*} == "$DATA_DIR" && $CFG_FILE != "$CREDS_FILE" ]] || fail 'Invalid metadata paths'
    for p in "$DATA_DIR" "$DESKTOP_HOME" "$RUNTIME_HOME" "$CFG_FILE" "$CREDS_FILE" "$STATE_FILE" "$JOURNAL_FILE" "$DATA_DIR/build" "$DATA_DIR/backups" "$DATA_DIR/logs" "$DATA_DIR/logs/manager.log" "$DATA_DIR/.lock" "$DATA_DIR/web-desktop.sh"; do
        [[ ! -L $p && $(realpath -m -- "$p") == "$p" ]] || fail "Symlink/noncanonical path: $p"
    done
    for p in "$DATA_DIR" "$DATA_DIR/build" "$DATA_DIR/backups" "$DATA_DIR/logs"; do
        if [[ -e $p ]]; then
            mode=$(stat -c '%a' "$p")
            [[ -d $p && $(stat -c '%u' "$p") == 0 ]] || fail "Unsafe directory ownership: $p"
            (( (8#$mode & 0022) == 0 )) || fail "Unsafe directory mode: $p"
        fi
    done
}
platform() {
    local key value distro='' major=''
    ((EUID == 0)) || fail 'Run as root; Podman is delegated to the dedicated user'
    while IFS='=' read -r key value; do
        value=${value//\"/}
        case $key in ID) distro=$value ;; VERSION_ID) major=${value%%.*} ;; esac
    done </etc/os-release
    case $distro:$major in rocky:9|rocky:10|almalinux:9|rhel:9) ;; *) fail 'Supported: Rocky 9/10, AlmaLinux/RHEL 9' ;; esac
}
default_config() {
    jq -n --arg owner "$OWNER" --arg runtime "$RUNTIME_USER" --arg name "$CONTAINER_NAME" --arg user "$DEFAULT_USER" \
        --arg address "$BIND_ADDRESS" --argjson port "$PORT" --arg image "$UPSTREAM_IMAGE" \
        --argjson networks "$(json_array "${ALLOWED_NETWORKS[@]}")" --argjson host "$(json_array "${HOST_PACKAGES[@]}")" \
        --argjson apps "$(json_array "${DESKTOP_PACKAGES[@]}")" --argjson glycin "$GLYCIN_COMPAT" \
        --argjson uid "$DESKTOP_UID" --argjson gid "$DESKTOP_GID" --arg tz "$TIMEZONE" --arg title "$DESKTOP_TITLE" \
        --arg memory "$MEMORY_LIMIT" --arg shm "$SHM_SIZE" --argjson pids "$PIDS_LIMIT" --argjson timeout "$READY_TIMEOUT" \
        '{schema:2,manager:$owner,runtime_mode:"rootless-pasta",runtime_user:$runtime,container_name:$name,username:$user,bind_address:$address,port:$port,allowed_networks:$networks,upstream_image:$image,host_packages:$host,desktop_packages:$apps,glycin_compat:$glycin,uid:$uid,gid:$gid,timezone:$tz,title:$title,memory:$memory,shm_size:$shm,pids_limit:$pids,ready_timeout:$timeout}'
}
validate_config() {
    jq -e --arg owner "$OWNER" --argjson keys "$(default_config | jq 'keys')" '
      def name: type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$");
      def integer($max): type=="number" and floor==. and .>=1 and .<=$max;
      def ipv4: type=="string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$") and (split(".")|all(.[]; (length==1 or (startswith("0")|not)) and (tonumber<=255)));
      def packages: type=="array" and all(.[];type=="string" and test("^[A-Za-z0-9][A-Za-z0-9+_.:@=~-]*$")) and length==(unique|length);
      (keys==$keys) and .schema==2 and .manager==$owner and .runtime_mode=="rootless-pasta" and
      (.runtime_user|type=="string" and test("^[a-z_][a-z0-9_-]{0,30}$")) and
      (.container_name|name) and (.username|name) and
      (.bind_address=="" or (.bind_address|ipv4 and (split(".")[0]|tonumber|.>0 and .!=127 and .<224))) and
      (.port|integer(65535)) and (.uid|integer(2147483647)) and (.gid|integer(2147483647)) and
      (.pids_limit|integer(1000000)) and (.ready_timeout|integer(900)) and
      (.host_packages|packages) and (.desktop_packages|packages) and
      ((["podman","passt","acl"]-.host_packages)|length==0) and
      (.allowed_networks|type=="array" and length>0 and length==(unique|length) and all(.[];type=="string" and (split("/")|length==2 and (.[0]|ipv4) and (.[1]|test("^[0-9]{1,2}$") and tonumber<=32)))) and
      (.upstream_image|type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_./:@-]+$")) and
      (.glycin_compat|type=="boolean") and
      ([.memory,.shm_size]|all(.[];type=="string" and test("^[1-9][0-9]*[kKmMgGtT]?$"))) and
      ([.timezone,.title]|all(.[];type=="string" and length>0 and (test("[\\x00-\\x1f]")|not)))
    ' <<<"$1" >/dev/null || fail 'Invalid configuration schema/values (rootful deployments require explicit migration)'
}
credentials() {
    local line key value seen_user=false seen_pass=false text
    text=$(secure_read "$CREDS_FILE")
    CUSTOM_USER='' PASSWORD=''
    while IFS= read -r line; do
        key=${line%%=*}; value=${line#*=}
        case $key in
            CUSTOM_USER) $seen_user && fail 'Duplicate credential'; CUSTOM_USER=$value; seen_user=true ;;
            PASSWORD) $seen_pass && fail 'Duplicate credential'; PASSWORD=$value; seen_pass=true ;;
            *) fail 'Invalid credentials; refusing regeneration' ;;
        esac
    done <<<"$text"
    [[ $CUSTOM_USER =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ && -n $PASSWORD && $PASSWORD != *$'\r'* ]] || fail 'Invalid credentials'
}
validate_state() {
    jq -e --arg owner "$OWNER" '.schema==1 and .manager==$owner and (.phase=="ready" or .phase=="prepared") and (.owned_rules|type=="array") and (.password_pending|type=="boolean")' <<<"$1" >/dev/null || fail 'Invalid state schema/owner'
    if [[ $(get .phase "$1") == ready ]]; then
        validate_config "$(get .applied "$1")"
        jq -e '.image|type=="string" and test("^localhost/[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+$")' <<<"$1" >/dev/null || fail 'Invalid managed image'
    fi
}
load() {
    STATE=
    if [[ -e $CFG_FILE ]]; then
        CONFIG=$(secure_read "$CFG_FILE"); validate_config "$CONFIG"
        STATE=$(secure_read "$STATE_FILE"); validate_state "$STATE"
        if [[ $(get .phase "$STATE") == ready ]]; then
            jq -e --argjson cfg "$CONFIG" '.applied.runtime_user==$cfg.runtime_user and .applied.container_name==$cfg.container_name' <<<"$STATE" >/dev/null || fail 'Identity changes require explicit migration'
        fi
        credentials
        [[ $CUSTOM_USER == "$(get .username)" ]] || fail 'Username differs from preserved credentials'
    else
        [[ ! -e $JOURNAL_FILE ]] || fail 'Orphan journal; restore metadata'
        if [[ -e $STATE_FILE ]]; then
            STATE=$(secure_read "$STATE_FILE"); validate_state "$STATE"
            jq -e '.phase=="prepared" and (.pending_config|type=="object") and (.home_initialized|type=="boolean")' <<<"$STATE" >/dev/null || fail 'Orphan state; restore metadata'
            CONFIG=$(get .pending_config "$STATE"); validate_config "$CONFIG"
            credentials
            [[ $CUSTOM_USER == "$(get .username)" ]] || fail 'Username differs from preserved credentials'
        else
            CONFIG=$(default_config); validate_config "$CONFIG"
        fi
    fi
}
identity() {
    local row name _unused gecos home shell
    RUNTIME_USER=$(get .runtime_user)
    row=$(getent passwd "$RUNTIME_USER") || fail 'Dedicated runtime user missing'
    IFS=: read -r name _unused RUID RGID gecos home shell <<<"$row"
    [[ $name == "$RUNTIME_USER" && $RUID =~ ^[0-9]+$ && $RUID != 0 && $home == "$RUNTIME_HOME" && $gecos == "$OWNER" && $shell == /sbin/nologin ]] || fail 'Refusing unrelated runtime user'
    if [[ -e $RUNTIME_HOME ]]; then
        [[ -d $RUNTIME_HOME && ! -L $RUNTIME_HOME && $(stat -c '%u:%a' "$RUNTIME_HOME") == "$RUID:700" ]] || fail 'Unsafe runtime home'
    fi
}
# Password is inherited only for create, not embedded into env command arguments.
pod() (
    [[ -n $RUID && $RUID != 0 ]] || fail 'Runtime identity not validated'
    cd /
    if [[ $1 == create ]]; then export CUSTOM_USER PASSWORD; else unset CUSTOM_USER PASSWORD; fi
    exec runuser -u "$RUNTIME_USER" -- env HOME="$RUNTIME_HOME" USER="$RUNTIME_USER" LOGNAME="$RUNTIME_USER" \
        XDG_DATA_HOME="$RUNTIME_HOME/.local/share" XDG_CONFIG_HOME="$RUNTIME_HOME/.config" \
        XDG_RUNTIME_DIR="/run/user/$RUID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$RUID/bus" podman "$@"
)
setup_runtime() {
    local path part acl file who start count valid key
    local -a parts
    RUNTIME_USER=$(get .runtime_user)
    if ! getent passwd "$RUNTIME_USER" >/dev/null; then
        [[ $COMMAND == install && ! -e $RUNTIME_HOME ]] || fail 'Missing runtime user'
        useradd --no-create-home --home-dir "$RUNTIME_HOME" --shell /sbin/nologin --comment "$OWNER" "$RUNTIME_USER"
    fi
    identity
    IFS=/ read -ra parts <<<"${DATA_DIR%/*}"
    path=
    for part in "${parts[@]}"; do
        [[ -n $part ]] || continue
        path+=/$part
        if ! runuser -u "$RUNTIME_USER" -- test -x "$path"; then
            [[ $(stat -c '%u' "$path") == 0 ]] || fail 'Inaccessible ancestor not root-owned'
            acl=$(getfacl -p -n -- "$path")
            [[ $acl != *'#effective:'* ]] || fail 'Masked ACL requires administrator review'
            printf '%s\n' "$acl" | atomic "$DATA_DIR/backups/ancestor-acl-$(random_hex).acl"
            setfacl -m "u:$RUID:--x" -- "$path"
            runuser -u "$RUNTIME_USER" -- test -x "$path" || fail 'Ancestor still inaccessible'
        fi
    done
    for key in uid gid; do
        file=/etc/sub$key; valid=false
        while IFS=: read -r who start count; do
            if [[ $who == "$RUNTIME_USER" || $who == "$RUID" ]]; then
                [[ $start =~ ^[0-9]+$ && $count =~ ^[0-9]+$ ]] || fail 'Invalid subid allocation'
                if (( count > $(get ".$key") )); then valid=true; fi
            fi
        done <"$file"
        $valid || fail "Missing/small subordinate allocation: $file"
    done
    if [[ ! -d $RUNTIME_HOME ]]; then install -d -m 700 -o "$RUID" -g "$RGID" "$RUNTIME_HOME"; fi
    loginctl enable-linger "$RUNTIME_USER"
    systemctl start "user@$RUID.service"
}
initialize_home() {
    mkdir -p -- "$DESKTOP_HOME"
    chmod 700 "$DESKTOP_HOME"
    chown "$RUID:$RGID" "$DESKTOP_HOME"
    pod unshare chown "$(get .uid):$(get .gid)" "$DESKTOP_HOME"
}
inspect() {
    local rc data
    if pod container exists "$1"; then :; else rc=$?; [[ $rc == 1 ]] && { printf 'null\n'; return; }; fail 'Cannot query Podman'; fi
    data=$(pod inspect --type container "$1")
    jq -e --arg owner "$OWNER" --arg home "$DESKTOP_HOME" 'length==1 and (.[0]|(.Id|test("^[a-f0-9]{64}$")) and .Config.Labels[$owner]=="true" and ([.Mounts[]|select(.Destination=="/config")]|length==1 and .[0].Source==$home) and (.State.Running|type=="boolean"))' <<<"$data" >/dev/null || fail 'Container ownership/mount/ID mismatch'
    jq '.[0]' <<<"$data"
}
start_container() {
    local info label
    info=$(inspect "$1"); [[ $info != null ]] || fail 'Missing managed container'
    [[ $(get .State.Running "$info") == true ]] && return 0
    label=$(jq -r '.MountLabel // ""' <<<"$info")
    if [[ -n $label ]]; then
        [[ $label =~ ^[a-zA-Z0-9_]+:object_r:container_file_t:s0(:c[0-9]+(,c[0-9]+)*)?$ ]] || fail 'Unexpected owned MountLabel'
        pod unshare chcon -R "$label" "$DESKTOP_HOME"
    elif [[ -e /sys/fs/selinux/enforce ]]; then fail 'Missing SELinux private mount label'; fi
    pod start "$1" >/dev/null
}
resolve_address() {
    local address
    address=$(jq -r .bind_address <<<"$CONFIG")
    [[ -z $EXPLICIT ]] || address=$EXPLICIT
    if [[ -z $address ]]; then address=$(ip -j -4 route get 1.1.1.1 | jq -er '[.[]|.prefsrc // .src]|unique|if length==1 then .[0] else error("Ambiguous IPv4") end'); fi
    CONFIG=$(jq --arg a "$address" '.bind_address=$a' <<<"$CONFIG")
    validate_config "$CONFIG"
    interface >/dev/null
}
interface() { ip -j -4 address show | jq -er --arg a "$(get .bind_address)" '[.[]|select(any(.addr_info[]; .local==$a))|.ifname]|if length==1 then .[0] else error("Host does not own one selected IPv4") end'; }
create_container() {
    credentials
    pod create --name "$(get .container_name)" --label "$OWNER=true" --restart=no --network pasta \
        --shm-size "$(get .shm_size)" --memory "$(get .memory)" --pids-limit "$(get .pids_limit)" \
        --env CUSTOM_USER --env PASSWORD -e "PUID=$(get .uid)" -e "PGID=$(get .gid)" -e "TZ=$(get .timezone)" -e "TITLE=$(get .title)" \
        -p "$(get .bind_address):$(get .port):3001" -v "$DESKTOP_HOME:/config:Z" --log-driver journald "$1" >/dev/null
}
http_status() {
    local secret
    if [[ $1 == auth ]]; then
        secret=$CUSTOM_USER:$PASSWORD; secret=${secret//\\/\\\\}; secret=${secret//\"/\\\"}
        printf 'user = "%s"\n' "$secret"
    fi | curl -q --config - --noproxy '*' --silent --insecure --max-time 3 --output /dev/null --write-out '%{http_code}' "https://$(get .bind_address):$(get .port)/"
}
ready() {
    local deadline=$((SECONDS + $(get .ready_timeout)))
    credentials
    while ((SECONDS < deadline)); do
        if [[ $(http_status anon) == 401 && $(http_status auth) == 200 ]] && pod exec "$(get .container_name)" pgrep -x xfce4-panel >/dev/null; then
            printf 'Ready: authenticated HTTPS and XFCE panel verified\n'; return
        fi
        sleep 2
    done
    fail 'Readiness failed; inspect logs'
}
rule_command() {
    $SKIP && fail 'Internal firewall guard: skip active'
    local -a args=()
    [[ $(get .permanent "$1") == true ]] && args+=(--permanent)
    firewall-cmd "${args[@]}" "--zone=$(get .zone "$1")" "$2$(get .rule "$1")" >/dev/null
}
rule_plan() {
    local zone network permanent rule entry rc present
    PLAN='[]'
    $SKIP && return 0
    [[ $(firewall-cmd --state) == running ]] || fail 'firewalld must already be active'
    zone=$(firewall-cmd "--get-zone-of-interface=$(interface)") || zone=
    if [[ -z $zone || $zone == 'no zone' ]]; then zone=$(firewall-cmd --get-default-zone); fi
    [[ $zone =~ ^[A-Za-z0-9_-]+$ ]] || fail 'Invalid firewalld zone'
    for permanent in false true; do
        while IFS= read -r network; do
            rule="rule family=\"ipv4\" source address=\"$network\" port port=\"$(get .port)\" protocol=\"tcp\" accept"
            entry=$(jq -n --arg z "$zone" --arg r "$rule" --argjson p "$permanent" '{zone:$z,rule:$r,permanent:$p}')
            if rule_command "$entry" --query-rich-rule=; then present=true; else rc=$?; [[ $rc == 1 ]] || fail 'Firewall query failed'; present=false; fi
            PLAN=$(jq --argjson e "$entry" --argjson p "$present" '.+[$e+{present:$p}]' <<<"$PLAN")
        done < <(jq -r '.allowed_networks[]' <<<"$CONFIG")
    done
}
build_image() {
    local generation directory packages
    pod pull "$(get .upstream_image)"
    DIGEST=$(pod image inspect "$(get .upstream_image)" --format '{{index .RepoDigests 0}}')
    [[ $DIGEST =~ ^[A-Za-z0-9_./:-]+@sha256:[a-f0-9]{64}$ ]] || fail 'Cannot pin upstream digest'
    generation=$(date -u +%Y%m%d%H%M%S)-$(random_hex)
    directory=$DATA_DIR/build/$generation
    mkdir -m 755 "$directory"
    packages=$(jq -r '.desktop_packages|join(" ")' <<<"$CONFIG")
    {
        printf 'FROM %s\n' "$DIGEST"
        [[ -z $packages ]] || printf 'RUN apk add --no-cache %s\n' "$packages"
        if [[ $(get .glycin_compat) == true ]]; then
            printf 'RUN apk add --no-cache bash && mv /usr/bin/bwrap /usr/bin/bwrap.real\nCOPY --chmod=755 bwrap-glycin /usr/bin/bwrap\n'
        fi
    } | atomic "$directory/Containerfile" 644
    cat <<'ADAPTER' | atomic "$directory/bwrap-glycin" 755
#!/bin/bash
set -euo pipefail
scoped=false
for arg in "$@"; do [[ $arg != /usr/libexec/glycin-loaders/* ]] || scoped=true; done
args=()
while (($#)); do
    if $scoped && [[ $1 == --dev && ${2:-} == /dev ]]; then
        args+=(--tmpfs /dev)
        for device in null zero random urandom; do args+=(--dev-bind "/dev/$device" "/dev/$device"); done
        shift 2
    else args+=("$1"); shift; fi
done
exec /usr/bin/bwrap.real "${args[@]}"
ADAPTER
    IMAGE=localhost/$(get .container_name):$generation
    pod build --no-cache -t "$IMAGE" "$directory"
}
validate_journal() {
    TRANSACTION=$(secure_read "$JOURNAL_FILE")
    jq -e --arg owner "$OWNER" --arg name "$(get .container_name)" '
      .manager==$owner and (.phase=="prepared" or .phase=="committed") and .name==$name and
      (.rollback_name|type=="string" and startswith($name+"-rollback-") and test("^[A-Za-z0-9_.-]+$")) and
      (.old_id==null or (.old_id|test("^[a-f0-9]{64}$"))) and (.was_running|type=="boolean") and
      (.plan|type=="array") and ((.skip_firewall_config // false)|type=="boolean")
    ' <<<"$TRANSACTION" >/dev/null || fail 'Invalid recovery journal'
    validate_state "$(get .previous "$TRANSACTION")"
    if $SKIP && [[ $(jq -r '.skip_firewall_config // false' <<<"$TRANSACTION") != true ]]; then
        fail 'Pending firewall-managed transaction: recover without --skip-firewall-config; firewall untouched'
    fi
    if [[ $(jq -r '.skip_firewall_config // false' <<<"$TRANSACTION") == true ]]; then
        [[ $(get '.plan|length' "$TRANSACTION") == 0 ]] || fail 'Unsafe skip journal contains firewall plan'
    fi
    if [[ $(get .phase "$TRANSACTION") == committed ]]; then validate_state "$(get .new_state "$TRANSACTION")"; fi
}
finish_transaction() {
    local entry rollback info
    STATE=$(get .new_state "$TRANSACTION")
    printf '%s\n' "$STATE" | atomic "$STATE_FILE"
    if [[ $(jq -r '.skip_firewall_config // false' <<<"$TRANSACTION") != true ]]; then
        while IFS= read -r entry; do rule_command "$entry" --remove-rich-rule=; done < <(jq -c '(.plan|map(del(.present))) as $desired | .previous.owned_rules[] | select(. as $key | $desired | index($key)==null)' <<<"$TRANSACTION")
    fi
    rollback=$(get .rollback_name "$TRANSACTION")
    info=$(inspect "$rollback")
    if [[ $info != null ]]; then
        [[ $(get .Id "$info") == "$(get .old_id "$TRANSACTION")" ]] || fail 'Rollback ID mismatch'
        pod rm "$rollback" >/dev/null
    fi
    rm -- "$JOURNAL_FILE"
    sync -f "$DATA_DIR"
}
recover() {
    [[ -e $JOURNAL_FILE ]] || return 0
    validate_journal
    if [[ $(get .phase "$TRANSACTION") == committed ]]; then finish_transaction; return; fi
    local name rollback old current saved entry desired=$CONFIG
    name=$(get .name "$TRANSACTION"); rollback=$(get .rollback_name "$TRANSACTION")
    old=$(jq -r '.old_id // ""' <<<"$TRANSACTION")
    current=$(inspect "$name"); saved=$(inspect "$rollback")
    if [[ $saved != null && $(get .Id "$saved") != "$old" ]]; then fail 'Rollback container ID mismatch'; fi
    if [[ $current != null && $(get .Id "$current") != "$old" ]]; then pod rm --force "$name" >/dev/null; current=null; fi
    if [[ $saved != null ]]; then pod rename "$rollback" "$name"; current=$saved; fi
    [[ -z $old || $current != null ]] || fail 'Original container missing; journal retained'
    if [[ $(jq -r '.skip_firewall_config // false' <<<"$TRANSACTION") != true ]]; then
        while IFS= read -r entry; do rule_command "$entry" --remove-rich-rule=; done < <(jq -c '.plan[]|select(.present==false)' <<<"$TRANSACTION")
    fi
    STATE=$(get .previous "$TRANSACTION")
    printf '%s\n' "$STATE" | atomic "$STATE_FILE"
    if [[ $current != null && $(get .was_running "$TRANSACTION") == true && $COMMAND != stop ]]; then
        CONFIG=$(get .applied "$STATE"); start_container "$name"; ready; CONFIG=$desired
    fi
    rm -- "$JOURNAL_FILE"; sync -f "$DATA_DIR"
    printf 'Previous deployment restored; home was not rolled back\n'
}
activate() {
    local start=$1 info old running name rollback entry owned newstate
    name=$(get .container_name); info=$(inspect "$name")
    old=$(jq -r '.Id // ""' <<<"$info"); running=$(jq -r '.State.Running // false' <<<"$info")
    rule_plan
    rollback=$name-rollback-$(random_hex)
    [[ $(inspect "$rollback") == null ]] || fail 'Rollback name collision'
    TRANSACTION=$(jq -n --arg owner "$OWNER" --arg name "$name" --arg rollback "$rollback" --arg old "$old" --argjson running "$running" --argjson prev "$STATE" --argjson plan "$PLAN" --argjson skip "$SKIP" '{manager:$owner,phase:"prepared",name:$name,rollback_name:$rollback,old_id:(if $old=="" then null else $old end),was_running:$running,previous:$prev,plan:$plan,skip_firewall_config:$skip}')
    printf '%s\n' "$TRANSACTION" | atomic "$JOURNAL_FILE"
    if [[ $info != null ]]; then
        if [[ $running == true ]]; then pod stop --time 30 "$name" >/dev/null; fi
        pod rename "$name" "$rollback"
    fi
    create_container "$IMAGE"
    while IFS= read -r entry; do rule_command "$entry" --add-rich-rule=; done < <(jq -c '.[]' <<<"$PLAN")
    if [[ $start == true ]]; then start_container "$name"; ready; fi
    if $SKIP; then owned=$(get .owned_rules "$STATE"); else
        owned=$(jq --argjson prev "$STATE" '[.[]|select(.present==false or (del(.present) as $key|$prev.owned_rules|index($key)!=null))|del(.present)]' <<<"$PLAN")
    fi
    newstate=$(jq --argjson cfg "$CONFIG" --arg image "$IMAGE" --arg digest "$DIGEST" --argjson owned "$owned" '.phase="ready"|.applied=$cfg|.image=$image|.base_digest=$digest|.owned_rules=$owned|del(.pending_config,.home_initialized)' <<<"$STATE")
    TRANSACTION=$(jq --argjson state "$newstate" '.phase="committed"|.new_state=$state' <<<"$TRANSACTION")
    printf '%s\n' "$TRANSACTION" | atomic "$JOURNAL_FILE"
    finish_transaction
}
# EXIT trap preserves journals on secondary recovery failure; no conditional
# function invocation that would silently disable Bash errexit in its body.
on_exit() {
    local rc=$?
    trap - EXIT INT TERM
    if ((rc != 0)) && [[ -e $JOURNAL_FILE && -n $RUID ]]; then
        printf 'Operation failed; attempting journal recovery\n' >&2
        set +e
        (set -Eeuo pipefail; recover)
        # Do not put recover in a conditional: that disables errexit in its body.
        # shellcheck disable=SC2181
        if (($? != 0)); then printf 'Recovery incomplete; journal retained for next modifying command\n' >&2; fi
    fi
    exit "$rc"
}
require_ready() { [[ -n $STATE && $(get .phase "$STATE") == ready ]] || fail 'Installation not ready; run install'; }
start_desktop() {
    CONFIG=$(get .applied "$STATE"); interface >/dev/null
    if [[ $(inspect "$(get .container_name)") == null ]]; then create_container "$(get .image "$STATE")"; fi
    start_container "$(get .container_name)"; ready
}
announce() {
    if [[ $(get .password_pending "$STATE") == true ]]; then
        credentials
        STATE=$(jq '.password_pending=false' <<<"$STATE"); printf '%s\n' "$STATE" | atomic "$STATE_FILE"
        printf 'Initial username: %s\nInitial password: %s\nSave securely; not recorded in manager logs.\n' "$CUSTOM_USER" "$PASSWORD"
    fi
}
install_cli() {
    local target=$DATA_DIR/web-desktop.sh link source
    link=/usr/local/bin/$(get .container_name).sh
    source=$(realpath -- "${BASH_SOURCE[0]}")
    if [[ -e $link || -L $link ]]; then [[ -L $link && $(readlink -- "$link") == "$target" ]] || fail 'Unrelated installed command'; fi
    if [[ $source != "$target" ]]; then atomic "$target" 750 <"$source"; fi
    [[ -L $link ]] || ln -s -- "$target" "$link"
}
reset_home() {
    local answer
    check_home_delete
    if ! $YES; then
        printf 'DELETE %s permanently. Type RESET: ' "$DESKTOP_HOME" >/dev/tty || fail 'No terminal; reset requires --yes'
        IFS= read -r answer </dev/tty || fail 'Reset cancelled'
        [[ $answer == RESET ]] || fail 'Reset cancelled'
    fi
    local info
    info=$(inspect "$(get .container_name)")
    if [[ $info != null ]]; then pod rm --force "$(get .container_name)" >/dev/null; fi
    check_home_delete
    rm -rf --one-file-system -- "$DESKTOP_HOME"
    initialize_home; start_desktop
}
check_home_delete() {
    local mount mounts
    [[ -d $DESKTOP_HOME && ! -L $DESKTOP_HOME && $(realpath "$DESKTOP_HOME") == "$DESKTOP_HOME" ]] || fail 'Unsafe home'
    mounts=$(findmnt -rn -o TARGET) || fail 'Cannot inspect mounts; refusing reset'
    while IFS= read -r mount; do
        [[ $mount != "$DESKTOP_HOME" && $mount != "$DESKTOP_HOME/"* ]] || fail 'Unmount nested home filesystems before reset'
    done <<<"$mounts"
}
main() {
    parse_cli "$@"
    platform; check_paths
    if ! command -v jq >/dev/null || ! command -v curl >/dev/null; then
        if ! $DRY && [[ $COMMAND == install || $COMMAND == update ]]; then dnf install -y jq curl; else fail 'Install jq and curl prerequisites; help/dry-run never install packages'; fi
    fi
    load
    [[ ! -e $JOURNAL_FILE ]] || validate_journal
    if $DRY; then
        [[ $COMMAND != update ]] || require_ready
        if [[ -n $STATE && $(get .phase "$STATE") == ready && $COMMAND == install ]]; then CONFIG=$(get .applied "$STATE"); fi
        resolve_address
        printf 'DRY RUN: no files/packages/containers/firewall changed.\nCommand: %s\nHome: %s\nSkip firewall: %s\n' "$COMMAND" "$DESKTOP_HOME" "$SKIP"
        jq '{bind_address,port,host_packages,desktop_packages,upstream_image,glycin_compat}' <<<"$CONFIG"
        return
    fi
    if [[ $COMMAND == status || $COMMAND == logs ]]; then
        if [[ -z $STATE || $(get .phase "$STATE") != ready ]]; then printf 'Not installed/ready\n'; exit 3; fi
        local desired=$CONFIG info
        CONFIG=$(get .applied "$STATE"); identity; info=$(inspect "$(get .container_name)")
        if [[ $COMMAND == status ]]; then
            printf 'Container: %s\nRunning: %s\nURL: https://%s:%s/\nImage: %s\nHome: %s\n' "$(get .container_name)" "$(jq -r '.State.Running // false' <<<"$info")" "$(get .bind_address)" "$(get .port)" "$(get .image "$STATE")" "$DESKTOP_HOME"
            printf 'Unapplied settings: %s\nRecovery journal: %s\nNo desktop boot autostart\n' "$(jq --argjson c "$CONFIG" '. != $c' <<<"$desired")" "$([[ -e $JOURNAL_FILE ]] && printf yes || printf no)"
        else
            [[ $info != null ]] || fail 'Container absent'
            local -a args=(--no-pager --output=cat --lines "$TAIL" "CONTAINER_ID_FULL=$(get .Id "$info")")
            $FOLLOW && args+=(--follow)
            journalctl "${args[@]}"
        fi
        return
    fi
    [[ -n $STATE || $COMMAND == install ]] || fail 'Not installed; run install'
    mkdir -p "$DATA_DIR"; chmod 711 "$DATA_DIR"
    [[ ! -e $DATA_DIR/.lock ]] || secure_read "$DATA_DIR/.lock" >/dev/null
    exec 9>"$DATA_DIR/.lock"; flock -n 9 || fail 'Another operation is running'
    load; [[ ! -e $JOURNAL_FILE ]] || validate_journal
    mkdir -p "$DATA_DIR/backups" "$DATA_DIR/build" "$DATA_DIR/logs"
    chmod 700 "$DATA_DIR/backups" "$DATA_DIR/logs"; chmod 711 "$DATA_DIR/build"
    if [[ -e $DATA_DIR/logs/manager.log ]]; then secure_read "$DATA_DIR/logs/manager.log" >/dev/null; fi
    printf '%s %s\n' "$(date -u +%FT%TZ)" "$COMMAND" >>"$DATA_DIR/logs/manager.log"
    if [[ $COMMAND == install || $COMMAND == update ]]; then
        local -a packages
        mapfile -t packages < <(jq -r '.host_packages[]' <<<"$CONFIG")
        dnf install -y jq curl "${packages[@]}"
    fi
    local runtime_desired=$CONFIG
    if [[ -n $STATE && $(get .phase "$STATE") == ready ]]; then
        case $COMMAND in start|stop|reset|install) CONFIG=$(get .applied "$STATE") ;; esac
    fi
    setup_runtime
    CONFIG=$runtime_desired
    trap on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    recover
    case $COMMAND in
        install)
            if [[ -n $STATE && $(get .phase "$STATE") == ready ]]; then
                [[ -z $EXPLICIT || $EXPLICIT == "$(get .applied.bind_address "$STATE")" ]] || fail 'Saved address differs; edit config and update'
                start_desktop; install_cli; announce; return
            fi
            resolve_address; rule_plan
            [[ $(inspect "$(get .container_name)") == null ]] || fail 'Container exists without ready state'
            if [[ -z $STATE ]]; then
                if [[ -d $DESKTOP_HOME ]]; then
                    local -a contents
                    shopt -s nullglob dotglob; contents=("$DESKTOP_HOME"/*); shopt -u nullglob dotglob
                    ((${#contents[@]} == 0)) || fail 'Refusing unmanaged nonempty home'
                fi
                local pending=false
                if [[ ! -e $CREDS_FILE ]]; then
                    PASSWORD=$(random_hex); CUSTOM_USER=$(get .username)
                    printf 'CUSTOM_USER=%s\nPASSWORD=%s\n' "$CUSTOM_USER" "$PASSWORD" | atomic "$CREDS_FILE"
                    pending=true
                fi
                credentials; [[ $CUSTOM_USER == "$(get .username)" ]] || fail 'Existing credentials username differs'
                STATE=$(jq -n --arg owner "$OWNER" --argjson pending "$pending" --argjson cfg "$CONFIG" '{schema:1,manager:$owner,phase:"prepared",owned_rules:[],password_pending:$pending,pending_config:$cfg,home_initialized:false}')
                printf '%s\n' "$STATE" | atomic "$STATE_FILE"
            fi
            if [[ $(get 'if has("home_initialized") then .home_initialized else true end' "$STATE") != true ]]; then
                if [[ -d $DESKTOP_HOME ]]; then
                    local -a partial_home
                    shopt -s nullglob dotglob; partial_home=("$DESKTOP_HOME"/*); shopt -u nullglob dotglob
                    ((${#partial_home[@]} == 0)) || fail 'Incomplete bootstrap has nonempty home; refusing ownership changes'
                fi
                initialize_home
                STATE=$(jq '.home_initialized=true' <<<"$STATE")
                printf '%s\n' "$STATE" | atomic "$STATE_FILE"
            fi
            printf '%s\n' "$CONFIG" | atomic "$CFG_FILE"
            build_image; activate true; install_cli; announce ;;
        update)
            require_ready; resolve_address
            local current running
            current=$(inspect "$(get .container_name)"); running=$(jq -r '.State.Running // false' <<<"$current")
            rule_plan; build_image
            printf '%s\n' "$STATE" | atomic "$DATA_DIR/backups/state-$(random_hex).json"
            activate "$running"; printf 'Updated; home/password and running/stopped state preserved\n' ;;
        start) require_ready; start_desktop ;;
        stop)
            require_ready
            local current
            current=$(inspect "$(get .container_name)")
            if [[ $current != null && $(get .State.Running "$current") == true ]]; then pod stop --time 30 "$(get .container_name)" >/dev/null; fi
            printf 'Stopped; home and credentials retained\n' ;;
        reset) require_ready; CONFIG=$(get .applied "$STATE"); reset_home ;;
    esac
}
main "$@"
