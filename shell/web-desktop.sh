#!/usr/bin/env bash
# DESC: Manage a persistent, manually started Podman web desktop.
# Copyright (c) 2026 Chris Ruettimann <chris@bitbull.ch>
# SPDX-License-Identifier: GPL-3.0-only
#
# This software is licensed under version 3 of the GNU General Public License.
# There is NO WARRANTY, including the implied warranties of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the repository LICENSE file or
# https://www.gnu.org/licenses/gpl-3.0.html for the full license text.
#
# =============================================================================
# Web Desktop Manager
# =============================================================================
# Purpose
#   A manually started Linux desktop in a web browser, based on LinuxServer
#   Webtop Alpine XFCE and rootless Podman with pasta. The standard environment provides
#   Chromium, an XFCE terminal, Thunar and an SSH client. Browser access uses
#   Selkies over HTTPS, not noVNC. No GPU is required for the standard desktop.
#
# Requirements
#   Root on Rocky Linux 9/10 or AlmaLinux / RHEL 9; Bash, Python 3, iproute and active
#   firewalld. Registry and package-repository access is needed for install/update.
#   The manager uses only Python's standard library; no pip packages are required.
#   Dedicated runtime user and persistent runtime home/storage under DATA_DIR/runtime.
#   loginctl linger and user@UID.service support rootless cgroups/session independence.
#   Host packages include acl. After runtime-user creation, inaccessible root-owned
#   DATA_DIR ancestors get a named UID execute-only ACL, never a shared-dir chmod.
#   Already traversable ancestors are untouched; non-root-owned blockers abort.
#   Before each change, getfacl -p -n is saved root-only under backups/ancestor-acl-*.acl.
#   setfacl recalculates the ACL mask (group mode bits reflect that mask); the named
#   user gets traversal, not directory listing/write. Existing masked ACL entries
#   cause an abort for administrator review, rather than broadening their access.
#   ACLs persist across reset/rollback. Review snapshots before manual restoration
#   with setfacl --restore=FILE; restoring may revoke runtime access or later edits.
#   Config/state/credentials remain root-only 0600; Podman subprocess cwd is /.
#
# Commands (use COMMAND --help for details)
#   install [--bind-address IPv4] [--dry-run]  Install/start or reuse installation.
#   start                                    Start the active desktop.
#   stop                                     Stop; retain data and credentials.
#   update [--dry-run]                        Apply saved config and rebuild image.
#   reset [--yes]                            DELETE home and start fresh.
#   status                                   Read-only deployment summary.
#   logs [--tail N] [--follow]                Display container/application logs.
#   --help / --version                       General help / manager version.
#   --yes is valid ONLY for reset. Without it, reset requires typing RESET.
#
# Configuration and persistence
#   Edit the defaults/package arrays below BEFORE first installation. Afterwards
#   CFG_FILE is authoritative: edit it, then run update. start/install reuse the
#   active configuration. state.json is manager-owned and must not be edited.
#   Home persists at DATA_DIR/home. Credentials are separate in CREDS_FILE.
#   A random initial password is printed once after successful installation and
#   excluded from the manager log. reset preserves credentials but permanently
#   deletes home, including browser profiles, SSH keys and the TLS certificate.
#   Webtop generates a self-signed certificate on first start (3650 days); reset
#   triggers a new certificate. No public CA, ACME or renewal service is installed.
#
# Operational/security boundaries
#   No desktop systemd unit, desktop boot autostart, automatic updates or privileged
#   mode/host socket. HTTPS port 8443 is allowed from RFC1918 IPv4 networks.
#   The user manager lingers at boot; the desktop has --restart=no.
#   Existing broader firewall rules are not narrowed. SELinux remains enabled.
#   The upstream desktop includes passwordless sudo INSIDE the container: this
#   is a private single-user desktop, not a hardened multi-tenant environment.
#   Update builds before replacing the container and supports activation rollback.
#   Rollback does not undo application changes to home or host package changes.
#   Metadata snapshots are NOT home backups. Old images/build history are retained.
#
# Additional applications: important limitation
#   DESKTOP_PACKAGES lists additional Alpine packages baked into the image.
#   The built-in PRoot Apps catalog is a separate, upstream-managed mechanism.
#   Catalog installation does NOT guarantee that an application will run here.
#   Some bundled AppImages need GPU/OpenGL features or kernel APIs restricted by
#   the container. Observed examples: Ghostty's AppImage lacks llvmpipe; Bitwarden
#   Desktop fails when secure-key initialization calls the blocked add_key syscall.
#   These are distinct compatibility problems, not a general X11 permission error.
#   No global graphics override, syscall exception or reduced password-manager
#   memory protection is installed by this script. Do not solve catalog failures
#   by blindly enabling --privileged or disabling seccomp/SELinux.
#   For broad desktop-app compatibility, prefer a VM with native distro packages.
#
# Implementation: one standalone file, Bash entrypoint + Python 3 standard library.
# =============================================================================
set -euo pipefail
umask 077

# Storage and identity (do not change these paths to migrate an installation).
DATA_DIR="/srv/docker/web-desktop"
CFG_FILE="${DATA_DIR}/config.json"
CREDS_FILE="${DATA_DIR}/credentials.env"
DEFAULT_USER="webdesktop"
RUNTIME_USER="webdesktop"
CONTAINER_NAME="web-desktop"

# Networking: empty address selects the default-route IPv4; no packets are sent.
BIND_ADDRESS=""
PORT=8443
ALLOWED_NETWORKS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)

# Image and packages: additional packages, not a removal list for the base image.
UPSTREAM_IMAGE="lscr.io/linuxserver/webtop:alpine-xfce"
HOST_PACKAGES=(podman passt acl)
DESKTOP_PACKAGES=(openssh-client)
GLYCIN_COMPAT=true

# Desktop and limits. No boot autostart, privileged mode or host socket.
DESKTOP_UID=1000
DESKTOP_GID=1000
TIMEZONE="Europe/Zurich"
DESKTOP_TITLE="Web Desktop"
MEMORY_LIMIT="2500m"
SHM_SIZE="1g"
PIDS_LIMIT=2048
READY_TIMEOUT=90

printf -v WD_HOST_PACKAGES '%s\n' "${HOST_PACKAGES[@]}"
printf -v WD_DESKTOP_PACKAGES '%s\n' "${DESKTOP_PACKAGES[@]}"
printf -v WD_NETWORKS '%s\n' "${ALLOWED_NETWORKS[@]}"
export RUNTIME_USER
export DATA_DIR CFG_FILE CREDS_FILE DEFAULT_USER CONTAINER_NAME BIND_ADDRESS PORT
export UPSTREAM_IMAGE GLYCIN_COMPAT DESKTOP_UID DESKTOP_GID TIMEZONE DESKTOP_TITLE
export MEMORY_LIMIT SHM_SIZE PIDS_LIMIT READY_TIMEOUT WD_HOST_PACKAGES WD_DESKTOP_PACKAGES WD_NETWORKS
export WEB_DESKTOP_SCRIPT_PATH
WEB_DESKTOP_SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
exec python3 - "$@" <<'PY'
"""Configuration, platform adapter and lifecycle are deliberately separate."""
import argparse
import base64
import copy
import datetime
import fcntl
import hashlib
import ipaddress
import json
import os
import pathlib
import pwd
import re
import secrets
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request

VERSION = '2.0'
OWNER = 'io.local.web-desktop.managed'
BASE = pathlib.Path(os.environ['DATA_DIR'])
CFG_FILE = pathlib.Path(os.environ['CFG_FILE'])
CREDS_FILE = pathlib.Path(os.environ['CREDS_FILE'])
STATE_FILE = BASE / 'state.json'
JOURNAL_FILE = BASE / 'transaction.json'
HOME = BASE / 'home'
RUNTIME_HOME = BASE / 'runtime'
SAFE_NAME = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}')
PACKAGE = re.compile(r'[A-Za-z0-9][A-Za-z0-9+_.:@=~-]*')
SIZE = re.compile(r'[1-9][0-9]*[kmgt]?', re.IGNORECASE)


def read_shell_defaults():
    env = os.environ
    return {
        'schema': 2, 'manager': OWNER,
        'runtime_mode': 'rootless-pasta', 'runtime_user': env['RUNTIME_USER'],
        'container_name': env['CONTAINER_NAME'], 'username': env['DEFAULT_USER'],
        'bind_address': env['BIND_ADDRESS'], 'port': int(env['PORT']),
        'allowed_networks': env['WD_NETWORKS'].split(),
        'upstream_image': env['UPSTREAM_IMAGE'],
        'host_packages': env['WD_HOST_PACKAGES'].split(),
        'desktop_packages': env['WD_DESKTOP_PACKAGES'].split(),
        'glycin_compat': env['GLYCIN_COMPAT'].lower() == 'true',
        'uid': int(env['DESKTOP_UID']), 'gid': int(env['DESKTOP_GID']),
        'timezone': env['TIMEZONE'], 'title': env['DESKTOP_TITLE'],
        'memory': env['MEMORY_LIMIT'], 'shm_size': env['SHM_SIZE'],
        'pids_limit': int(env['PIDS_LIMIT']), 'ready_timeout': int(env['READY_TIMEOUT']),
    }

# Capture shell defaults once. Saved configuration is the sole source afterwards.
DEFAULTS = read_shell_defaults()


def default_settings():
    return copy.deepcopy(DEFAULTS)


def validate_settings(config):
    cfg = copy.deepcopy(config)
    if set(cfg) != set(DEFAULTS):
        raise RuntimeError('Configuration keys differ: ' + str(sorted(set(cfg) ^ set(DEFAULTS))))
    if cfg['schema'] != 2 or cfg['manager'] != OWNER:
        raise RuntimeError('Unrecognized configuration schema/owner')
    if cfg['runtime_mode'] != 'rootless-pasta':
        raise RuntimeError('Only rootless-pasta is supported')
    if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,30}', cfg['runtime_user']):
        raise RuntimeError('Invalid runtime_user')
    for key in ('container_name', 'username'):
        if not isinstance(cfg[key], str) or not SAFE_NAME.fullmatch(cfg[key]):
            raise RuntimeError('Invalid setting: ' + key)
    if not isinstance(cfg['bind_address'], str):
        raise RuntimeError('bind_address must be an IPv4 string')
    if cfg['bind_address']:
        address = ipaddress.IPv4Address(cfg['bind_address'])
        if address.is_unspecified or address.is_multicast or address.is_loopback:
            raise RuntimeError('Use one assigned non-loopback IPv4 address')
    for key, maximum in (('port', 65535), ('uid', 2147483647), ('gid', 2147483647),
                         ('pids_limit', 1000000), ('ready_timeout', 900)):
        if type(cfg[key]) is not int or not 1 <= cfg[key] <= maximum:
            raise RuntimeError('Invalid positive integer: ' + key)
    for key in ('host_packages', 'desktop_packages'):
        if not isinstance(cfg[key], list) or not all(isinstance(p, str) and PACKAGE.fullmatch(p) for p in cfg[key]):
            raise RuntimeError('Invalid package list: ' + key)
        if len(cfg[key]) != len(set(cfg[key])):
            raise RuntimeError('Duplicate packages: ' + key)
    if not {'podman', 'passt', 'acl'} <= set(cfg['host_packages']):
        raise RuntimeError('host_packages must include podman, passt and acl')
    if not isinstance(cfg['allowed_networks'], list) or not cfg['allowed_networks']:
        raise RuntimeError('allowed_networks must be a nonempty IPv4 CIDR list')
    cfg['allowed_networks'] = [str(ipaddress.IPv4Network(net)) for net in cfg['allowed_networks']]
    if len(cfg['allowed_networks']) != len(set(cfg['allowed_networks'])):
        raise RuntimeError('Duplicate allowed_networks')
    if not isinstance(cfg['upstream_image'], str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_./:@-]+', cfg['upstream_image']):
        raise RuntimeError('Invalid upstream_image reference')
    if type(cfg['glycin_compat']) is not bool:
        raise RuntimeError('glycin_compat must be true or false')
    for key in ('memory', 'shm_size'):
        if not isinstance(cfg[key], str) or not SIZE.fullmatch(cfg[key]):
            raise RuntimeError('Invalid Podman size: ' + key)
    for key in ('timezone', 'title'):
        if not isinstance(cfg[key], str) or not cfg[key] or any(c in cfg[key] for c in '\n\r\0'):
            raise RuntimeError('Invalid setting: ' + key)
    return cfg


BWRAP = '''#!/usr/bin/python3
# Scope the device-mount workaround to Glycin; keep namespace/seccomp isolation.
import os
import sys
args = sys.argv[1:]
if any(arg.startswith('/usr/libexec/glycin-loaders/') for arg in args):
    adjusted = []
    index = 0
    while index < len(args):
        if args[index:index + 2] == ['--dev', '/dev']:
            adjusted.extend(['--tmpfs', '/dev'])
            for device in ('null', 'zero', 'random', 'urandom'):
                adjusted.extend(['--dev-bind', '/dev/' + device, '/dev/' + device])
            index += 2
        else:
            adjusted.append(args[index])
            index += 1
    args = adjusted
os.execv('/usr/bin/bwrap.real', ['bwrap'] + args)
'''


# ---- Pure renderers: all runtime choices come from the saved configuration. ----
def endpoint(config):
    suffix = '' if config['port'] == 443 else ':' + str(config['port'])
    return 'https://' + config['bind_address'] + suffix + '/'


def render_containerfile(config, digest):
    lines = ['FROM ' + digest]
    if config['desktop_packages']:
        lines.append('RUN apk add --no-cache ' + ' '.join(config['desktop_packages']))
    if config['glycin_compat']:
        lines += ['RUN mv /usr/bin/bwrap /usr/bin/bwrap.real',
                  'COPY --chmod=755 bwrap-glycin /usr/bin/bwrap']
    return '\n'.join(lines) + '\n'


def container_arguments(config, image):
    return ['podman', 'create', '--name', config['container_name'], '--label', OWNER + '=true',
            '--restart=no', '--network', 'pasta', '--shm-size', config['shm_size'],
            '--memory', config['memory'], '--pids-limit', str(config['pids_limit']),
            '--env', 'CUSTOM_USER', '--env', 'PASSWORD', '-e', 'PUID=' + str(config['uid']),
            '-e', 'PGID=' + str(config['gid']), '-e', 'TZ=' + config['timezone'],
            '-e', 'TITLE=' + config['title'], '-p', config['bind_address'] + ':' + str(config['port']) + ':3001',
            '-v', str(HOME) + ':/config:Z', '--log-driver', 'journald', image]


def firewall_rule(network, config):
    return 'rule family="ipv4" source address="' + network + '" port port="' + str(config['port']) + '" protocol="tcp" accept'


# ---- File safety, platform checks, and subprocess adapter. ----
def atomic(path, text, mode=0o600):
    if path.is_symlink():
        raise RuntimeError('Refusing symlink: ' + str(path))
    temp = path.with_name('.' + path.name + '-' + secrets.token_hex(5))
    try:
        with temp.open('x') as file:
            os.chmod(temp, mode)
            file.write(text)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temp.unlink(missing_ok=True)


def save_json(path, value):
    atomic(path, json.dumps(value, indent=2, sort_keys=True) + '\n')


def secure_read(path):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError('Expected a regular file: ' + str(path))
    stat = path.stat()
    if stat.st_uid != 0 or stat.st_mode & 0o077:
        raise RuntimeError('Expected root ownership and mode 0600: ' + str(path))
    return path.read_text()


def read_credentials():
    result = {}
    for line in secure_read(CREDS_FILE).splitlines():
        key, separator, value = line.partition('=')
        if separator:
            result[key] = value
    if set(result) != {'CUSTOM_USER', 'PASSWORD'} or not SAFE_NAME.fullmatch(result['CUSTOM_USER']) or not result['PASSWORD']:
        raise RuntimeError('Invalid credentials.env; refusing to regenerate credentials')
    return result


def check_paths():
    if not BASE.is_absolute() or len(BASE.parts) < 3:
        raise RuntimeError('DATA_DIR must be a dedicated absolute application directory')
    paths = (BASE, HOME, RUNTIME_HOME, CFG_FILE, CREDS_FILE, STATE_FILE, JOURNAL_FILE,
             BASE / 'logs', BASE / 'logs/manager.log', BASE / 'build', BASE / 'backups', BASE / 'web-desktop.sh')
    if any(path.is_symlink() or path.resolve() != path for path in paths):
        raise RuntimeError('Symlinks in managed data paths are not supported')
    reserved = {'runtime', 'home', 'state.json', 'transaction.json', 'logs', 'build', 'backups', 'web-desktop.sh'}
    if CFG_FILE.parent != BASE or CREDS_FILE.parent != BASE or CFG_FILE == CREDS_FILE:
        raise RuntimeError('CFG_FILE/CREDS_FILE must be distinct direct files in DATA_DIR')
    if CFG_FILE.name in reserved or CREDS_FILE.name in reserved:
        raise RuntimeError('Configuration paths conflict with managed files')
    if BASE.exists() and (BASE.stat().st_uid != 0 or BASE.stat().st_mode & 0o022):
        raise RuntimeError('DATA_DIR must be root-owned and not group/world-writable')


def check_platform():
    values = dict(line.split('=', 1) for line in pathlib.Path('/etc/os-release').read_text().splitlines() if '=' in line)
    distro = values.get('ID', '').strip('"')
    major = values.get('VERSION_ID', '').strip('"').split('.')[0]
    if not ((distro in ('rocky', 'almalinux', 'rhel') and major == '9') or (distro == 'rocky' and major == '10')):
        raise RuntimeError('Supported host platforms: Rocky 9/10, AlmaLinux/RHEL 9')
    if os.geteuid() != 0:
        raise RuntimeError('Run as root; the host manager delegates Podman to a dedicated runtime user')


def check_home_delete():
    if not HOME.is_dir() or HOME.is_symlink() or HOME.resolve() != HOME:
        raise RuntimeError('Unsafe or missing home directory')
    for line in pathlib.Path('/proc/self/mountinfo').read_text().splitlines():
        mount = pathlib.Path(line.split()[4].replace('\\040', ' ').replace('\\134', '\\'))
        if mount == HOME or HOME in mount.parents:
            raise RuntimeError('Unmount nested home filesystems before reset')


def confirm_reset(yes):
    if yes:
        return
    try:
        with open('/dev/tty', 'w') as output, open('/dev/tty', 'r') as response:
            output.write('DELETE ' + str(HOME) + ' permanently (no backup). Type RESET: ')
            output.flush()
            answer = response.readline().strip()
    except OSError as error:
        raise RuntimeError('No terminal: reset requires --yes; nothing deleted') from error
    if answer != 'RESET':
        raise RuntimeError('Reset cancelled; nothing deleted')


def journal_arguments(container_id, tail, follow):
    # Rootless users may not read the system journal. The administrative CLI
    # reads only the exact managed container, without granting journal groups.
    command = ['journalctl', '--no-pager', '--output=cat', '--lines', str(tail),
               'CONTAINER_ID_FULL=' + container_id]
    if follow:
        command.append('--follow')
    return command


class Commands:
    def __init__(self):
        self.logfile = None
        self.runtime = None

    def log(self, message):
        print(message, flush=True)
        if self.logfile:
            self.logfile.write(message + '\n')
            self.logfile.flush()

    def open_log(self):
        (BASE / 'logs').mkdir(exist_ok=True, mode=0o700)
        self.logfile = (BASE / 'logs/manager.log').open('a')

    def close(self):
        if self.logfile:
            self.logfile.close()
            self.logfile = None

    def invocation(self, args):
        env = {'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
               'LANG': 'C.UTF-8'}
        if args[0] != 'podman':
            return args, env
        if self.runtime is None:
            raise RuntimeError('Rootless runtime identity has not been configured')
        user = self.runtime
        if args[1] == 'create':
            env.update(read_credentials())
        command = ['runuser', '-u', user.pw_name, '--', 'env',
                   'HOME=' + user.pw_dir, 'USER=' + user.pw_name, 'LOGNAME=' + user.pw_name,
                   'XDG_DATA_HOME=' + user.pw_dir + '/.local/share',
                   'XDG_CONFIG_HOME=' + user.pw_dir + '/.config',
                   'XDG_RUNTIME_DIR=/run/user/' + str(user.pw_uid),
                   'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/' + str(user.pw_uid) + '/bus']
        return command + list(args), env

    def run(self, *args, check=True, stream=False, timeout=60):
        command, env = self.invocation(args)
        if stream:
            import threading
            self.log('Running: ' + ' '.join(args[:2]))
            process = subprocess.Popen(command, env=env, cwd='/', text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            def copy_output():
                for line in process.stdout:
                    self.log(line.rstrip())
            reader = threading.Thread(target=copy_output, daemon=True)
            reader.start()
            try:
                code = process.wait(timeout=timeout)
            except BaseException:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
            finally:
                reader.join(timeout=5)
                process.stdout.close()
            result = subprocess.CompletedProcess(args, code, '', '')
        else:
            result = subprocess.run(command, env=env, cwd='/', text=True, capture_output=True, timeout=timeout)
        if check and result.returncode:
            raise RuntimeError('Command failed: ' + ' '.join(args[:2]) + ' (exit ' + str(result.returncode) + '): ' + result.stderr.strip())
        return result

    def text(self, *args):
        return self.run(*args).stdout.strip()


# ---- Manager: desired config, credentials and active state have separate owners. ----
class Manager:
    def __init__(self, commands=None):
        self.cmd = commands or Commands()
        self.config = None
        self.state = None

    def runtime_identity(self, cfg):
        try:
            user = pwd.getpwnam(cfg['runtime_user'])
        except KeyError as error:
            raise RuntimeError('Dedicated runtime user is missing; run install') from error
        if (user.pw_uid == 0 or user.pw_dir != str(RUNTIME_HOME)
                or user.pw_gecos != OWNER or user.pw_shell != '/sbin/nologin'):
            raise RuntimeError('Unrelated runtime user; refusing to adopt ' + cfg['runtime_user'])
        if RUNTIME_HOME.exists():
            stat = RUNTIME_HOME.stat()
            if RUNTIME_HOME.is_symlink() or stat.st_uid != user.pw_uid or stat.st_mode & 0o077:
                raise RuntimeError('Unsafe runtime home ownership or permissions')
        return user

    def setup_runtime(self, cfg, create=False):
        if create:
            try:
                pwd.getpwnam(cfg['runtime_user'])
            except KeyError:
                if RUNTIME_HOME.exists():
                    raise RuntimeError('Runtime home exists without its managed user')
                self.cmd.run('useradd', '--no-create-home', '--home-dir', str(RUNTIME_HOME),
                             '--shell', '/sbin/nologin', '--comment', OWNER, cfg['runtime_user'])
        user = self.runtime_identity(cfg)
        # Walk from / down so a blocked parent cannot make an accessible child
        # appear blocked. Never chmod shared ancestors or touch accessible ones.
        for ancestor in reversed(BASE.parents):
            probe = ('runuser', '-u', user.pw_name, '--', 'test', '-x', str(ancestor))
            result = self.cmd.run(*probe, check=False)
            if result.returncode == 0:
                continue
            if result.returncode != 1:
                raise RuntimeError('Cannot test runtime traversal: ' + str(ancestor))
            if ancestor.stat().st_uid != 0:
                raise RuntimeError('Inaccessible ancestor is not root-owned: ' + str(ancestor))
            original = self.cmd.run('getfacl', '-p', '-n', '--', str(ancestor)).stdout
            if '#effective:' in original:
                raise RuntimeError('Existing masked ACL requires administrator review: ' + str(ancestor))
            backup = BASE / 'backups' / ('ancestor-acl-' + secrets.token_hex(8) + '.acl')
            atomic(backup, original)
            self.cmd.log('Backing up ancestor ACL: ' + str(ancestor) + ' -> ' + str(backup))
            self.cmd.run('setfacl', '-m', 'u:' + str(user.pw_uid) + ':--x', '--', str(ancestor))
            if self.cmd.run(*probe, check=False).returncode != 0:
                raise RuntimeError('Runtime still cannot traverse ancestor: ' + str(ancestor))
        for filename, key in (('/etc/subuid', 'uid'), ('/etc/subgid', 'gid')):
            ranges = [line.split(':') for line in pathlib.Path(filename).read_text().splitlines()]
            if not any(len(row) == 3 and row[0] in (user.pw_name, str(user.pw_uid))
                       and int(row[2]) > cfg[key] for row in ranges):
                raise RuntimeError('Missing/small subordinate ID allocation in ' + filename)
        if not RUNTIME_HOME.exists():
            RUNTIME_HOME.mkdir(mode=0o700)
            os.chown(RUNTIME_HOME, user.pw_uid, user.pw_gid)
        self.cmd.runtime = user
        self.cmd.run('loginctl', 'enable-linger', user.pw_name)
        self.cmd.run('systemctl', 'start', 'user@' + str(user.pw_uid) + '.service')

    def initialize_home(self, cfg):
        user = self.cmd.runtime
        os.chown(HOME, user.pw_uid, user.pw_gid)
        self.cmd.run('podman', 'unshare', 'chown', str(cfg['uid']) + ':' + str(cfg['gid']), str(HOME))

    def inspect(self, name, owned=True):
        found = self.cmd.run('podman', 'container', 'exists', name, check=False)
        if found.returncode == 1:
            return None
        if found.returncode:
            raise RuntimeError('Cannot query Podman state')
        info = json.loads(self.cmd.text('podman', 'inspect', '--type', 'container', name))[0]
        if owned:
            if info.get('Config', {}).get('Labels', {}).get(OWNER) != 'true':
                raise RuntimeError('Unrelated container: ' + name)
            if not any(m.get('Source') == str(HOME) and m.get('Destination') == '/config' for m in info.get('Mounts', [])):
                raise RuntimeError('Managed container has an unexpected home mount')
        return info

    def load(self):
        if not CFG_FILE.exists():
            return False
        raw = json.loads(secure_read(CFG_FILE))
        if raw.get('runtime_mode') != 'rootless-pasta':
            raise RuntimeError('Existing rootful deployment requires explicit migration; preserve credentials/home and archive old metadata first')
        self.config = validate_settings(raw)
        if not STATE_FILE.exists():
            raise RuntimeError('state.json is missing; restore it instead of silently rebuilding an unknown deployment')
        self.state = json.loads(secure_read(STATE_FILE))
        if self.state.get('manager') != OWNER or self.state.get('schema') != 1 or self.state.get('phase') not in ('prepared', 'ready'):
            raise RuntimeError('Unrecognized runtime state')
        if self.state['phase'] == 'ready':
            if self.state.get('applied', {}).get('runtime_mode') != 'rootless-pasta':
                raise RuntimeError('Existing rootful runtime requires explicit migration')
            validate_settings(self.state['applied'])
            if self.config['runtime_user'] != self.state['applied']['runtime_user']:
                raise RuntimeError('Changing runtime_user requires explicit migration')
            if self.config['container_name'] != self.state['applied']['container_name']:
                raise RuntimeError('Changing container_name on an existing installation is not supported')
            if not isinstance(self.state.get('image'), str) or not self.state['image'].startswith('localhost/' + self.state['applied']['container_name'] + ':'):
                raise RuntimeError('Invalid managed image state')
        if self.config['username'] != read_credentials()['CUSTOM_USER']:
            raise RuntimeError('Configuration username differs from credentials; no automatic credential changes are performed')
        return True

    def resolve_address(self, cfg, explicit=None):
        result = copy.deepcopy(cfg)
        address = explicit or cfg['bind_address']
        if not address:
            routes = json.loads(self.cmd.text('ip', '-j', '-4', 'route', 'get', '1.1.1.1'))
            candidates = {r.get('prefsrc') or r.get('src') for r in routes} - {None}
            if len(candidates) != 1:
                raise RuntimeError('Cannot select one IPv4 address; set bind_address explicitly')
            address = candidates.pop()
        result['bind_address'] = address
        result = validate_settings(result)
        self.interface(result)
        return result

    def interface(self, cfg):
        for item in json.loads(self.cmd.text('ip', '-j', '-4', 'address', 'show')):
            if any(a.get('local') == cfg['bind_address'] for a in item.get('addr_info', [])):
                return item['ifname']
        raise RuntimeError('Host does not own IPv4 address ' + cfg['bind_address'])

    def check_port(self, cfg):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind((cfg['bind_address'], cfg['port']))
            except OSError as error:
                raise RuntimeError('Address/port occupied: ' + endpoint(cfg)) from error

    def rule_plan(self, cfg):
        if self.cmd.text('firewall-cmd', '--state') != 'running':
            raise RuntimeError('firewalld must already be active; the manager does not enable services')
        interface = self.interface(cfg)
        result = self.cmd.run('firewall-cmd', '--get-zone-of-interface=' + interface, check=False)
        zone = result.stdout.strip()
        if result.returncode or zone in ('', 'no zone'):
            zone = self.cmd.text('firewall-cmd', '--get-default-zone')
        entries = []
        for permanent in (False, True):
            for network in cfg['allowed_networks']:
                entry = {'zone': zone, 'permanent': permanent, 'rule': firewall_rule(network, cfg)}
                query = self.rule_command(entry, '--query-rich-rule=', check=False)
                if query.returncode not in (0, 1):
                    raise RuntimeError('Cannot query firewalld rule')
                entry['present'] = query.returncode == 0
                entries.append(entry)
        return entries

    def rule_command(self, entry, operation, check=True):
        extra = ['--permanent'] if entry['permanent'] else []
        return self.cmd.run('firewall-cmd', *extra, '--zone=' + entry['zone'], operation + entry['rule'], check=check)

    def build(self, cfg):
        self.cmd.log('Pulling and building the desktop before changing the active container...')
        self.cmd.run('podman', 'pull', cfg['upstream_image'], stream=True, timeout=900)
        digest = self.cmd.text('podman', 'image', 'inspect', cfg['upstream_image'], '--format', '{{index .RepoDigests 0}}')
        if not re.fullmatch(r'[A-Za-z0-9_./:-]+@sha256:[a-f0-9]{64}', digest):
            raise RuntimeError('Cannot resolve a pinned upstream digest')
        generation = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S') + '-' + secrets.token_hex(3)
        directory = BASE / 'build' / generation
        directory.mkdir(parents=True, mode=0o755)
        os.chmod(directory, 0o755)
        atomic(directory / 'Containerfile', render_containerfile(cfg, digest), 0o644)
        if cfg['glycin_compat']:
            atomic(directory / 'bwrap-glycin', BWRAP, 0o755)
        image = 'localhost/' + cfg['container_name'] + ':' + generation
        self.cmd.run('podman', 'build', '--no-cache', '-t', image, str(directory), stream=True, timeout=900)
        return image, digest

    def http_status(self, cfg, authenticated):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                   urllib.request.HTTPSHandler(context=ssl._create_unverified_context()))
        request = urllib.request.Request(endpoint(cfg))
        if authenticated:
            values = read_credentials()
            token = base64.b64encode((values['CUSTOM_USER'] + ':' + values['PASSWORD']).encode()).decode()
            request.add_header('Authorization', 'Basic ' + token)
        try:
            with opener.open(request, timeout=3) as response:
                return response.status
        except urllib.error.HTTPError as error:
            return error.code

    def ready(self, cfg):
        deadline = time.monotonic() + cfg['ready_timeout']
        while time.monotonic() < deadline:
            try:
                if self.http_status(cfg, False) == 401 and self.http_status(cfg, True) == 200:
                    panel = self.cmd.run('podman', 'exec', cfg['container_name'], 'pgrep', '-x', 'xfce4-panel', check=False)
                    if panel.returncode == 0:
                        self.cmd.log('Ready: authenticated HTTPS and XFCE panel verified')
                        return
            except (OSError, urllib.error.URLError):
                pass
            time.sleep(2)
        raise RuntimeError('Readiness failed; use the logs command for diagnostics')

    def setup_directories(self):
        BASE.mkdir(parents=True, exist_ok=True, mode=0o711)
        os.chmod(BASE, 0o711)
        for name in ('backups', 'build', 'logs'):
            (BASE / name).mkdir(exist_ok=True, mode=0o700)
        os.chmod(BASE / 'build', 0o711)
        self.cmd.open_log()

    def install_cli(self):
        link = pathlib.Path('/usr/local/bin') / (self.config['container_name'] + '.sh')
        target = BASE / 'web-desktop.sh'
        if (link.exists() or link.is_symlink()) and (not link.is_symlink() or link.resolve() != target):
            raise RuntimeError('Refusing to overwrite unrelated command: ' + str(link))
        source = pathlib.Path(os.environ['WEB_DESKTOP_SCRIPT_PATH'])
        if source.resolve() != target:
            atomic(target, source.read_text(), 0o750)
        if not link.is_symlink():
            link.symlink_to(target)

    @staticmethod
    def rule_key(entry):
        return {key: entry[key] for key in ('zone', 'permanent', 'rule')}

    def remove_if_owned(self, name):
        if self.inspect(name):
            self.cmd.run('podman', 'rm', '--force', name)

    def finish_transaction(self, transaction):
        # The commit journal is durable before state.json; finish that write after a crash.
        save_json(STATE_FILE, transaction['new_state'])
        self.state = transaction['new_state']
        desired = [self.rule_key(e) for e in transaction['plan']]
        for entry in transaction['previous'].get('owned_rules', []):
            if entry not in desired:
                self.rule_command(entry, '--remove-rich-rule=')
        if self.inspect(transaction['rollback_name']):
            self.cmd.run('podman', 'rm', transaction['rollback_name'])
        JOURNAL_FILE.unlink()

    def recover(self, force_stopped=False):
        if not JOURNAL_FILE.exists():
            return
        transaction = json.loads(secure_read(JOURNAL_FILE))
        if transaction.get('manager') != OWNER:
            raise RuntimeError('Unrecognized recovery journal')
        if transaction['phase'] == 'committed':
            self.finish_transaction(transaction)
            return
        self.cmd.log('Recovering the previous container and runtime state...')
        previous = transaction['previous']
        name = transaction['name']
        current = self.inspect(name)
        rollback = self.inspect(transaction['rollback_name'])
        if current and current['Id'] != transaction['old_id']:
            self.cmd.run('podman', 'rm', '--force', name)
            current = None
        if rollback:
            if rollback['Id'] != transaction['old_id']:
                raise RuntimeError('Recovery container ID mismatch')
            self.cmd.run('podman', 'rename', transaction['rollback_name'], name)
            current = rollback
        if transaction['old_id'] and not current:
            raise RuntimeError('Previous container missing; recovery journal retained for inspection')
        for entry in transaction['plan']:
            if not entry['present']:
                self.rule_command(entry, '--remove-rich-rule=')
        save_json(STATE_FILE, previous)
        self.state = previous
        if current and transaction['was_running'] and not force_stopped:
            self.start_container(name)
            self.ready(previous['applied'])
        JOURNAL_FILE.unlink()
        self.cmd.log('Previous deployment restored; home data was not rolled back')

    def activate(self, cfg, image, digest, start):
        previous = copy.deepcopy(self.state)
        name = cfg['container_name']
        current = self.inspect(name)
        plan = self.rule_plan(cfg)
        rollback_name = name + '-rollback-' + secrets.token_hex(4)
        transaction = {'manager': OWNER, 'phase': 'prepared', 'name': name,
                       'rollback_name': rollback_name, 'old_id': current['Id'] if current else None,
                       'was_running': bool(current and current['State']['Running']), 'previous': previous, 'plan': plan}
        save_json(JOURNAL_FILE, transaction)
        committed = False
        try:
            if current:
                if current['State']['Running']:
                    self.cmd.run('podman', 'stop', '--time', '30', name)
                self.cmd.run('podman', 'rename', name, rollback_name)
            self.cmd.run(*container_arguments(cfg, image))
            for entry in plan:
                self.rule_command(entry, '--add-rich-rule=')
            if start:
                self.start_container(name)
                self.ready(cfg)
            owned = [self.rule_key(e) for e in plan if not e['present'] or self.rule_key(e) in previous.get('owned_rules', [])]
            new_state = {'schema': 1, 'manager': OWNER, 'phase': 'ready', 'image': image,
                         'base_digest': digest, 'applied': copy.deepcopy(cfg), 'owned_rules': owned,
                         'password_pending': previous.get('password_pending', False)}
            transaction['phase'] = 'committed'
            transaction['new_state'] = new_state
            save_json(JOURNAL_FILE, transaction)
            committed = True
            save_json(STATE_FILE, new_state)
            self.state = new_state
            self.finish_transaction(transaction)
        except BaseException:
            if not committed:
                self.recover()
            raise

    def announce_password(self):
        if self.state.get('password_pending'):
            self.state['password_pending'] = False
            save_json(STATE_FILE, self.state)
            values = read_credentials()
            # Deliberately bypass logging. Never include credentials in argv.
            print('Initial username: ' + values['CUSTOM_USER'], flush=True)
            print('Initial password: ' + values['PASSWORD'], flush=True)
            print('Save these credentials securely; the password is not in manager.log.', flush=True)

    def install(self, explicit):
        if self.state and self.state['phase'] == 'ready':
            if explicit and explicit != self.state['applied']['bind_address']:
                raise RuntimeError('Saved address differs; edit config.json and use update')
            self.install_cli()
            self.start()
            self.announce_password()
            return
        cfg = self.resolve_address(self.config or default_settings(), explicit)
        self.check_port(cfg)
        self.rule_plan(cfg)
        if not self.state and HOME.exists() and any(HOME.iterdir()):
            raise RuntimeError('Refusing to adopt an unmanaged nonempty home')
        self.cmd.log('Host packages: ' + ', '.join(cfg['host_packages']))
        self.cmd.run('dnf', 'install', '-y', *cfg['host_packages'], stream=True, timeout=900)
        self.setup_runtime(cfg, create=True)
        if self.inspect(cfg['container_name']):
            raise RuntimeError('Container exists without ready runtime state')
        if not HOME.exists():
            HOME.mkdir(mode=0o700)
        if not any(HOME.iterdir()):
            self.initialize_home(cfg)
        if not self.state:
            pending = not CREDS_FILE.exists()
            if pending:
                atomic(CREDS_FILE, 'CUSTOM_USER=' + cfg['username'] + '\nPASSWORD=' + secrets.token_urlsafe(24) + '\n')
            elif read_credentials()['CUSTOM_USER'] != cfg['username']:
                raise RuntimeError('Existing username differs; credentials were preserved')
            self.state = {'schema': 1, 'manager': OWNER, 'phase': 'prepared', 'owned_rules': [], 'password_pending': pending}
            save_json(STATE_FILE, self.state)
        read_credentials()
        self.config = cfg
        save_json(CFG_FILE, cfg)
        image, digest = self.build(cfg)
        self.activate(cfg, image, digest, start=True)
        self.install_cli()
        self.announce_password()

    def require_ready(self):
        if not self.state or self.state['phase'] != 'ready':
            raise RuntimeError('Installation is not ready; run install (safe to retry)')
        return self.state['applied']

    def start_container(self, name):
        current = self.inspect(name)
        if not current:
            raise RuntimeError('Managed container missing: ' + name)
        if current['State']['Running']:
            return  # Idempotent start: never relabel a live desktop.
        # Podman's :Z can skip descendants already hidden behind mode-0700
        # directories with an old MCS label. Traverse as namespace root, using
        # only this owned container's private label and managed home subtree.
        label = current.get('MountLabel', '')
        if label:
            self.cmd.run('podman', 'unshare', 'chcon', '-R', label, str(HOME))
        self.cmd.run('podman', 'start', name)

    def start(self):
        cfg = self.require_ready()
        self.interface(cfg)
        current = self.inspect(cfg['container_name'])
        if not current or not current['State']['Running']:
            self.check_port(cfg)
        if not current:
            self.cmd.run(*container_arguments(cfg, self.state['image']))
        self.start_container(cfg['container_name'])
        self.ready(cfg)
        if self.config != cfg:
            self.cmd.log('Configuration has unapplied changes; use update to apply them')

    def stop(self):
        cfg = self.require_ready()
        current = self.inspect(cfg['container_name'])
        if current and current['State']['Running']:
            self.cmd.run('podman', 'stop', '--time', '30', cfg['container_name'])
        self.cmd.log('Stopped; home retained, no boot autostart')

    def update(self):
        old = self.require_ready()
        cfg = self.resolve_address(self.config)
        current = self.inspect(old['container_name'])
        running = bool(current and current['State']['Running'])
        if not running or (old['bind_address'], old['port']) != (cfg['bind_address'], cfg['port']):
            self.check_port(cfg)
        self.rule_plan(cfg)
        self.cmd.run('dnf', 'install', '-y', *cfg['host_packages'], stream=True, timeout=900)
        image, digest = self.build(cfg)
        save_json(BASE / 'backups' / ('state-' + secrets.token_hex(6) + '.json'), self.state)
        self.activate(cfg, image, digest, start=running)
        self.cmd.log('Updated; previous running/stopped state and home preserved')

    def reset(self, yes):
        cfg = self.require_ready()
        self.interface(cfg)
        check_home_delete()
        confirm_reset(yes)
        self.remove_if_owned(cfg['container_name'])
        shutil.rmtree(HOME)
        HOME.mkdir(mode=0o700)
        self.initialize_home(cfg)
        self.start()
        self.cmd.log('Home reset completed; credentials retained')

    def status(self):
        if not self.config:
            print('Not installed')
            return 3
        print('Configuration: ' + str(CFG_FILE))
        print('Home: ' + str(HOME))
        print('Username: ' + self.config['username'])
        print('No boot autostart; no automatic updates')
        if self.state['phase'] != 'ready':
            print('Installation incomplete; run install to resume')
            return 3
        cfg = self.state['applied']
        current = self.inspect(cfg['container_name'])
        print('Container: ' + cfg['container_name'] + ' / ' + ('running' if current and current['State']['Running'] else 'stopped or absent'))
        print('Active URL: ' + endpoint(cfg))
        print('Image: ' + self.state['image'])
        print('Unapplied configuration changes: ' + str(self.config != cfg))
        print('Recovery journal present: ' + str(JOURNAL_FILE.exists()))
        return 0

    def plan(self, command, explicit):
        if command == 'install' and self.state and self.state['phase'] == 'ready':
            active = self.state['applied']
            if explicit and explicit != active['bind_address']:
                raise RuntimeError('Saved address differs; edit config.json and use update')
            print('DRY RUN: reuse/start active deployment at ' + endpoint(active))
            print('No build, package installation, password rotation or configuration application.')
            print('The executable copy/symlink is refreshed; rootful metadata requires explicit migration.')
            print('No changes performed by this dry-run.')
            return
        if command == 'update':
            self.require_ready()
        cfg = self.resolve_address(self.config or default_settings(), explicit)
        print('DRY RUN: no files, packages, containers, credentials or firewall rules changed.')
        print('Command: ' + command + '; desired URL: ' + endpoint(cfg))
        print('Host packages: ' + ', '.join(cfg['host_packages']))
        print('Additional desktop packages: ' + (', '.join(cfg['desktop_packages']) or '(none)'))
        print('Upstream image: ' + cfg['upstream_image'])
        print('Persistent home: ' + str(HOME))
        print('Firewall sources: ' + ', '.join(cfg['allowed_networks']))
        print('Glycin compatibility adapter: ' + str(cfg['glycin_compat']))
        print('Credentials: preserve existing or generate once on first install; never shown by dry-run.')
        print('No desktop bootstart; runtime user linger/user manager enabled. Update preserves running/stopped state.')


# ---- CLI: options belong only to the commands that implement them. ----
OVERVIEW = f'''Web Desktop Manager {VERSION}: Alpine XFCE in a browser, managed by Podman.

Quick start:  web-desktop.sh install
Management:   web-desktop.sh start | stop | update | reset | status | logs
Help:         web-desktop.sh COMMAND --help

Defaults and package arrays are at the top of this standalone script.
First install saves them to {CFG_FILE}. Afterwards edit that JSON file and use
update; install/start never silently apply changed runtime settings.
Credentials: {CREDS_FILE}; home: {HOME}.
Runtime state is separate in {STATE_FILE}; do not edit state.json.

Defaults: username {DEFAULTS["username"]}, HTTPS {DEFAULTS["port"]}; no bootstart.
Allowed IPv4 sources: {", ".join(DEFAULTS["allowed_networks"])}.
Root, Bash/Python 3, Rocky 9/10 or AlmaLinux/RHEL 9 and active firewalld are required.
Podman runs as a dedicated Linux runtime user (separate from HTTP identity).
Inaccessible root-owned DATA_DIR ancestors receive only a named runtime UID --x
ACL; already traversable ancestors are unchanged, non-root-owned blockers abort.
No shared-directory chmod or world-open access is added. Before each ACL change,
getfacl -p -n is saved root-only in backups/ancestor-acl-*.acl. setfacl recalculates
the mask (visible as group mode bits); masked existing ACLs require administrator
review before any change. The new user entry grants traversal only. ACLs survive reset
and rollback. Review before manual setfacl --restore=FILE: later ACL edits may
be overwritten and runtime access revoked. Podman subprocesses use cwd /.
Linger and user@UID.service are enabled, but no desktop unit or restart policy.
Old rootful deployments require explicit migration; they are not silently adopted.
Other operating systems are rejected before installation actions.
Host package list: {", ".join(DEFAULTS["host_packages"])}.
Additional desktop package list: {", ".join(DEFAULTS["desktop_packages"]) or "(none)"}.
Chromium, Thunar and XFCE already belong to the base image.
Removing packages from an ADDITIONAL list does not remove base-image packages.

APPLICATION COMPATIBILITY: the PRoot Apps catalog is separate from the image's
Alpine package list. Installed catalog apps are not guaranteed to work in this
container. Ghostty's bundled graphics stack and Bitwarden's kernel-keyring needs
are known examples. No blanket graphics/security bypass is configured here.
Use a VM with native packages when broad desktop-app compatibility is required.

Security: rootless nonprivileged container, no host socket, SELinux :Z home mount,
HTTP Basic auth, self-signed certificate. The upstream desktop includes sudo.
This is a private single-user desktop, not a hardened multi-tenant boundary.
No outside CA/ACME, GPU passthrough, reboot, scheduler or external log collector.

Files: {CFG_FILE.name} (desired), state.json (active), {CREDS_FILE.name}, home/,
logs/manager.log, build/<generation>/, backups/, optional transaction.json.
An executable copy and /usr/local/bin/<container_name>.sh symlink are installed.
Runtime HOME: {RUNTIME_HOME}; rootless storage: runtime/.local/share/containers.
Runtime user: {DEFAULTS["runtime_user"]}; runtime HOME/storage survive reset.
Config/state/credentials remain root-only; only home is mounted in the desktop.
No automatic image/history pruning. No home backups are made by this manager.
Container defaults: memory {DEFAULTS["memory"]}, shared memory {DEFAULTS["shm_size"]},
PIDs {DEFAULTS["pids_limit"]}, UID/GID {DEFAULTS["uid"]}/{DEFAULTS["gid"]}, timezone {DEFAULTS["timezone"]}.
Package dependencies can update host runtime/SELinux packages. They are not removed
on rollback. TLS is image-generated self-signed (3650 days), retained in home/ssl
until reset deletes it. Existing broader firewall rules are not narrowed.
Glycin compatibility is default-enabled: a scoped device-mount adapter, not a
blanket sandbox disable. Disable via config only after verifying upstream support.
'''


def parse_args(argv=None):
    parser = argparse.ArgumentParser(prog='web-desktop.sh', description=OVERVIEW,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--version', action='version', version=VERSION)
    parser.set_defaults(bind_address=None, dry_run=False, yes=False, follow=False, tail=100)
    commands = parser.add_subparsers(dest='command', required=True)
    descriptions = {
        'install': '''Install and start, or resume/reuse an existing installation.
No option is required. The initial address is selected from the optional override,
then the script BIND_ADDRESS default, then a local default-route lookup.
An existing saved address is preserved. Host packages, image, persistent home,
root-only credentials and private HTTPS firewall rules are prepared explicitly.
A random initial password is displayed once after success, never in the log.
Repeated install reuses the image/password/home. It does not apply edited config;
use update for that. No automatic bootstart is installed.

Examples: web-desktop.sh install
          web-desktop.sh install --dry-run
          web-desktop.sh install --bind-address 192.0.2.10''',
        'start': '''Start the active deployment, recreate its container if missing.
Preserves image, password and home. Does not pull/build or apply edited config.
After reboot the desktop remains stopped until this command is used.
Example: web-desktop.sh start''',
        'stop': '''Stop the desktop; keep home, password, configuration and images.
Safe when already stopped. Firewall rules remain; the desktop listener closes.
Example: web-desktop.sh stop''',
        'update': '''Apply saved configuration and rebuild from a fresh upstream image.
Build happens before stopping the existing container. Preserve running/stopped
state, credentials and home. Keep the original container until replacement passes
readiness; restore it if activation fails. A recovery journal handles interrupted
activation on the next modifying command. Old images/config snapshots are retained.
Image rollback cannot undo application migrations in home files; back up home
separately before high-impact updates. Host package additions are not rolled back.
Only manager-owned stale firewall rules are removed; unrelated rules are preserved.
Example: web-desktop.sh update''',
        'reset': f'''Permanently delete {HOME} and start a fresh desktop.
Removes browser profiles, downloads, SSH keys, settings and TLS certificate.
Password, config and installed image are retained. A new certificate is generated.
There is no backup and no undo. Type RESET at a terminal to confirm.
Noninteractive use requires the explicit confirmation option below.
Example: web-desktop.sh reset''',
        'status': '''Read-only summary: active URL/image, running state, unapplied config and
pending recovery. Passwords are never printed. Exit code 3 means not installed/ready.
Example: web-desktop.sh status''',
        'logs': '''Show Podman container logs. No lifecycle changes are made.
Application logs may contain application-generated sensitive data.
Example: web-desktop.sh logs --tail 50''',
    }
    for name, description in descriptions.items():
        child = commands.add_parser(name, description=description, help=description.splitlines()[0],
                                    formatter_class=argparse.RawDescriptionHelpFormatter)
        if name == 'install':
            child.add_argument('--bind-address', metavar='HOST_IPV4', help='Optional assigned host IPv4 override on first install')
        if name in ('install', 'update'):
            child.add_argument('--dry-run', action='store_true', help='Read-only plan; no downloads, writes, password generation or service changes')
        if name == 'reset':
            child.add_argument('--yes', action='store_true', help='RESET ONLY: confirm permanent home deletion without a prompt')
        if name == 'logs':
            child.add_argument('--follow', action='store_true', help='Follow new container log output until Ctrl-C')
            child.add_argument('--tail', type=int, default=100, metavar='N', help='Number of lines (default 100)')
    args = parser.parse_args(argv)
    if args.tail < 0 or args.tail > 100000:
        parser.error('--tail must be between 0 and 100000')
    return args


def main():
    args = parse_args()
    check_platform()
    check_paths()
    validate_settings(DEFAULTS)
    manager = Manager()
    loaded = manager.load()
    if args.command in ('status', 'logs') and loaded and manager.state['phase'] == 'ready':
        manager.cmd.runtime = manager.runtime_identity(manager.state['applied'])
    if args.command == 'status':
        return manager.status()
    if args.command == 'logs':
        cfg = manager.require_ready()
        container = manager.inspect(cfg['container_name'])
        if not container:
            raise RuntimeError('Container is absent')
        return subprocess.call(journal_arguments(container['Id'], args.tail, args.follow), cwd='/')
    if args.dry_run:
        manager.plan(args.command, args.bind_address)
        return 0
    if not loaded and args.command != 'install':
        raise RuntimeError('Not installed; run install')
    # Fixed per-data-directory lock: a name edit cannot bypass concurrent-operation exclusion.
    lock_id = hashlib.sha256(str(BASE).encode()).hexdigest()[:16]
    with open('/run/lock/web-desktop-' + lock_id + '.lock', 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError('Another operation is running for ' + str(BASE)) from error
        manager.load()  # Re-read after acquiring the lock.
        manager.setup_directories()
        try:
            manager.cmd.log(datetime.datetime.now(datetime.timezone.utc).isoformat() + ' ' + args.command)
            if manager.state and (manager.state['phase'] == 'ready' or JOURNAL_FILE.exists()):
                manager.setup_runtime(manager.state.get('applied', manager.config))
            manager.recover(force_stopped=args.command == 'stop')
            if args.command == 'install':
                manager.install(args.bind_address)
            elif args.command == 'start':
                manager.start()
            elif args.command == 'stop':
                manager.stop()
            elif args.command == 'update':
                manager.update()
            elif args.command == 'reset':
                manager.reset(args.yes)
            if manager.state and manager.state['phase'] == 'ready':
                manager.cmd.log('Active URL: ' + endpoint(manager.state['applied']))
            manager.cmd.log('No boot autostart. Use start after reboot.')
        except BaseException as error:
            manager.cmd.log('FAILED: ' + str(error))
            raise
        finally:
            manager.cmd.close()
    return 0


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Operation interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('Interrupted. Pending transactions recover on the next modifying command.', file=sys.stderr)
        sys.exit(130)
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
PY
