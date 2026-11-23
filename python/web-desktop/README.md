# Web Desktop Manager

A single-file manager for a private Linux desktop in your browser: Alpine XFCE, Chromium, Thunar and an SSH client, running in rootless Podman with pasta. The desktop is started manually, not at host boot.

The executable is `web-desktop.sh`. Bash provides the editable defaults and package arrays; Python 3's standard library implements typed configuration, atomic state files, subprocess control and transaction recovery. No Python packages or companion files are needed on the target.

## Application compatibility: intended scope

This manager is suitable for the standard desktop/browser/SSH/file-manager workflow. It is **not a guarantee that arbitrary applications from the built-in PRoot Apps catalog will run without adaptation**. The catalog packages are managed upstream and are distinct from the native Alpine packages in `DESKTOP_PACKAGES`.

Two failures were reproduced in this deployment:

- **Ghostty AppImage 1.4.0:** bundled Mesa lacks llvmpipe. Without a usable GPU, its fallback cannot provide Ghostty's required OpenGL context. An app-scoped guest-Mesa override was tested successfully, but no permanent launcher or global override was installed. Upstream [issue #176](https://github.com/pkgforge-dev/ghostty-appimage/issues/176) was open at verification.
- **Bitwarden Desktop:** `keyctl()` succeeds, but the active Podman seccomp profile blocks `add_key()` with ENOSYS. Bitwarden's backend support detection then leads to a startup panic. The related [containers/common PR #2487](https://github.com/containers/common/pull/2487) was closed without merging because of rootful-container security concerns. No syscall exception or memory-protection downgrade was applied.

These are separate problems, not a general X11-socket permission failure. Do not disable SELinux/seccomp or enable privileged mode as a blanket fix. Use a conventional VM with native packages when broad desktop-app compatibility is a requirement; changing the base image alone does not remove container security boundaries.

These compatibility investigations do not constitute a guarantee that arbitrary catalog applications will run.

## Quick start

As root on Rocky Linux 9/10 or AlmaLinux/RHEL 9 with active firewalld:

```sh
./web-desktop.sh install --dry-run
./web-desktop.sh install
```

No address argument is required. On first installation, the manager selects the source IPv4 address of the default route. This is a local kernel lookup, not a connection to an external server. The optional `BIND_ADDRESS` script default or `install --bind-address ADDRESS` overrides detection. An explicit address must belong to the host.

Installation starts the desktop and prints the URL, initial username and randomly generated password. The password is shown once on successful initial installation, saved root-only, and excluded from the manager log. The default username `webdesktop` is the **HTTPS Basic-auth username**, not the Linux account inside the image (normally `abc`).

After installation, `web-desktop.sh` is available through `/usr/local/bin/web-desktop.sh`. HTTPS defaults to port 8443 with a self-signed certificate. Accept the certificate warning only after verifying that you reached the intended host.

## Commands and their options

| Command | Effect | Options besides `-h` / `--help` |
|---|---|---|
| `install` | First installation, safe retry of an incomplete install, or reuse/start the existing deployment | `--bind-address HOST_IPV4`, `--dry-run` |
| `start` | Start the active configuration; recreate the container if absent | None |
| `stop` | Stop; retain home, credentials, config and images | None |
| `update` | Apply saved configuration and rebuild from the upstream image; preserve running/stopped state | `--dry-run` |
| `reset` | Permanently delete the home, recreate and start using the active image/config | `--yes` |
| `status` | Read-only state, active URL/image, unapplied changes, recovery indication | None |
| `logs` | Read the host journal filtered by the exact managed container ID | `--tail N` (default 100), `--follow` |

Global options: `--help`, `--version`.

```sh
web-desktop.sh install --help
web-desktop.sh reset --help
web-desktop.sh logs --tail 50 --follow
```

`--yes` belongs **only to reset**. Other commands reject it. Without it, reset requires typing `RESET` on a terminal; without a terminal it refuses. No home backup is made by reset.

Exit codes: 0 success, 1 operational error, 2 invalid CLI syntax/options, 3 not installed/ready from status, 130 interrupted operation.

## Configuration: one source of truth

### Before installation

Edit the defaults at the beginning of the script:

```bash
DEFAULT_USER="webdesktop"
PORT=8443
BIND_ADDRESS=""
HOST_PACKAGES=(podman passt acl)
DESKTOP_PACKAGES=(openssh-client)
ALLOWED_NETWORKS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)
```

Other defaults cover storage paths, container name, upstream image, Glycin compatibility, UID/GID, timezone, desktop title, memory/shared memory/PID limits and readiness timeout.

### After installation

The saved file **`/srv/docker/web-desktop/config.json`** is authoritative. Edit its settings, then run:

```sh
web-desktop.sh update --dry-run
web-desktop.sh update
```

For example, change just the existing `desktop_packages` value to:

```json
["openssh-client", "htop"]
```

Do not replace the entire configuration with that fragment. Unknown keys, wrong types, malformed names and invalid values are rejected before activation.

**Editing script defaults does not silently override an installed deployment.** `install` and `start` keep the active configuration; `status` reports unapplied config edits. `update` applies them. Existing host/data paths, container identity and credentials are not automatically migrated by changing defaults.

### Settings reference

| Saved key | Default | Meaning |
|---|---|---|
| `username` | `webdesktop` | Initial HTTPS username; must match the credentials file. No automatic account changes. |
| `container_name` | `web-desktop` | Container identity; changing an installed identity is rejected. |
| `bind_address` | Auto-detected, then saved | Specific host IPv4; no all-interface listener. |
| `port` | `8443` | Host HTTPS port; container HTTPS remains 3001. |
| `allowed_networks` | RFC1918 ranges | IPv4 source CIDRs for runtime/permanent firewalld rich rules. |
| `upstream_image` | `lscr.io/linuxserver/webtop:alpine-xfce` | Must be a compatible Alpine Webtop image; package installation uses apk. |
| `host_packages` | `podman`, `passt`, `acl` | Host runtime and execute-only ACL tools; required packages. Extras may be added. |
| `runtime_user` | `webdesktop` | Dedicated, non-login host account for rootless Podman; unrelated existing accounts are rejected. |
| `runtime_mode` | `rootless-pasta` | Required execution mode; old rootful state is not silently migrated. |
| `desktop_packages` | `openssh-client` | Additional packages installed in the derived image; an empty list is supported. |
| `glycin_compat` | `true` | Scoped Alpine image-loader compatibility adapter. |
| `uid`, `gid` | `1000`, `1000` | Desktop user IDs for the persistent home; IDs inside the container, mapped to subordinate host IDs; these are not the runtime account UID/GID. |
| `timezone` | `Europe/Zurich` | Container timezone. |
| `title` | `Web Desktop` | Browser desktop title. |
| `memory` | `2500m` | Container RAM limit. |
| `shm_size` | `1g` | Shared-memory maximum. |
| `pids_limit` | `2048` | Container process limit. |
| `ready_timeout` | `90` | Readiness timeout in seconds. |

Do not edit the `schema` and `manager` ownership fields. The runtime state is stored separately and must not be manually edited.

### Package-list semantics

The host and desktop lists are deliberately separate. Rebuilding starts from a fresh pinned base digest, then installs the desired **additional** desktop packages. Chromium, Thunar and XFCE already belong to the base image: removing them from the additional list cannot uninstall them. Host packages and their dependencies are not removed when they disappear from the host list or an image activation rolls back.

## Storage and created artifacts

| Path | Purpose |
|---|---|
| `/srv/docker/web-desktop/config.json` | Desired settings, root-only |
| `/srv/docker/web-desktop/state.json` | Active image, applied settings, owned firewall entries and install state, root-only |
| `/srv/docker/web-desktop/credentials.env` | HTTPS username/password, root-only |
| `/srv/docker/web-desktop/home/` | Persistent container `/config`, including browser profiles, downloads, SSH files and TLS files |
| `/srv/docker/web-desktop/build/<generation>/` | Pinned Containerfile and optional adapter source |
| `/srv/docker/web-desktop/backups/` | Previous config/state metadata, **not** home backups |
| `/srv/docker/web-desktop/logs/manager.log` | Operation/build diagnostics; no generated password |
| `/srv/docker/web-desktop/transaction.json` | Temporary durable activation/recovery journal |
| `/srv/docker/web-desktop/web-desktop.sh` | Installed copy of the standalone manager |
| `/usr/local/bin/<container_name>.sh` | Symlink to installed copy |
| `/run/lock/web-desktop-<path-hash>.lock` | Exclusive lock per data directory |
| Podman's system storage, `/srv/docker/web-desktop/runtime/.local/share/containers` | Images, build cache and container layers |
| journald | Container output; no external collector is installed |

`DATA_DIR`, `CFG_FILE` and `CREDS_FILE` are bootstrap paths at the top of the script. Config and credentials must be distinct direct files in DATA_DIR, outside the resettable home. Symlinked managed paths and unsafe data-directory permissions are rejected.

The script does not install a desktop systemd unit, timer or cron job. It explicitly uses `--restart=no`. It does enable linger and start `user@UID.service` for the dedicated runtime account; that user manager may start at boot, but the desktop does not. After a host reboot the desktop remains stopped. Use SSH and `web-desktop.sh start` when needed. There is no automatic reboot, image update or pruning.

## Credentials, TLS and reset

On fresh installation a random password is generated and stored with root-only permissions. It is shown once after successful startup, not in the manager log. If a first build fails, retrying install preserves the credential and displays it when installation eventually succeeds. A surviving credential file is never rotated simply because configuration is missing.

The Webtop image generates a self-signed certificate with OpenSSL when `home/ssl/cert.pem` is missing. Validity is 3650 days; the private key is `home/ssl/cert.key` with mode 0600. No public CA, ACME client or certificate renewal service is installed.

`stop`, `start`, repeated `install` and `update` retain home and credentials. **`reset` deletes the entire home**, including profiles, downloads, SSH keys and TLS certificate, but keeps credentials and manager configuration outside home. The next start creates a fresh desktop and certificate, so the certificate fingerprint changes. Reset does not apply pending desired-config changes; use update for that.

## Update and recovery guarantees

1. Validate configuration/address and inspect current ownership/state.
2. Install requested host packages and build the new image **before** stopping the desktop.
3. Save a transaction journal and retain the old container under a temporary rollback name.
4. Create the replacement, apply intended firewall additions and, if it was running, verify HTTPS authentication and the XFCE panel.
5. Commit the active state, remove stale manager-owned firewall entries, then remove the rollback container.
6. If activation fails, restore the **original container** and previous running/stopped state. A pending journal is recovered on the next modifying command. Explicit `stop` does not restart the recovered desktop.

A build failure leaves the working container running. If the desktop was stopped, update leaves the replacement stopped; its UI can only be checked when subsequently started. Previously existing unrelated firewall rules are not claimed or removed. Old images and build/state history are retained for investigation; disk capacity must be monitored.

**Limits:** image/container rollback cannot undo application changes already written to the home, and host package changes are not rolled back. Back up home separately before high-impact updates. Hard filesystem loss or manual deletion of the rollback container still needs operator recovery. Status/dry-run report a pending journal without changing it.

## Existing rootful installations

Legacy rootful metadata is rejected rather than silently reusing its home or image references. Migration requires an explicit administrator procedure: back up configuration/credentials and the stopped home; create the managed runtime identity; copy the home through `podman unshare` so container numeric ownership is preserved under the subordinate-ID mapping; prepare rootless configuration and state; install and verify the replacement. Keep the stopped rootful container and home backup until acceptance. Retire its old firewall rules only after the replacement is verified. Do not point both running containers at the same home.

The rootful and rootless image stores are separate, so migration downloads/builds the image again. The existing HTTP password and TLS files can be retained; migration is not a reset.

## Security and operational scope

- OS allowlist: Rocky Linux 9/10 and AlmaLinux/RHEL 9. Debian/Ubuntu and other releases are rejected before installation. Runtime validation targets Rocky Linux on x86-64; AlmaLinux/RHEL are not separately runtime-tested.
- Root-run administrative CLI, but rootless container/build execution under a dedicated account. No privileged container, host socket or host networking.
- User-space pasta forwarding, avoiding the rootful bridge/DNAT path. SELinux stays enforcing; private home labels must match the active container, including after replacement/rollback.
- Default source rules cover private IPv4 networks. Existing broader host rules are not narrowed; inspect overall firewall policy.
- Upstream Webtop includes passwordless sudo inside the desktop. This is not a hardened kiosk or multi-tenant boundary.
- Software rendering by default. No GPU passthrough is configured.
- Runtime dependencies may update host networking/runtime/SELinux policy packages.
- Container/application logs can contain application-generated sensitive data even though the manager excludes generated passwords from its own log.

### Glycin compatibility

The tested Alpine image's image loader attempted a nested devpts mount that failed on the host. The adapter affects only Glycin's bubblewrap invocation: a minimal tmpfs `/dev` with null/zero/random/urandom replaces the problematic synthetic device setup. Namespace/seccomp isolation remains enabled. Other bubblewrap commands are unchanged. Revalidate this workaround against future upstream images before disabling `glycin_compat`.

## Validation

Local tests use the Python standard library:

```sh
bash -n web-desktop.sh
python3 -m unittest discover -s tests -v
```

Tests cover typed configuration, command-specific flags, unsupported OS rejection, rootless execution/environment, runtime-account isolation and home/reset boundaries. Runtime checks must also exercise initial install, repeated install, stop/start, update, reset on disposable data, authenticated browser rendering and both allowed/denied network sources. Do not run reset against a user's existing home as a test.

### Runtime acceptance (2026-11-22)

- Rocky Linux 9.7 / Podman 5.8.5: migrated an existing desktop to rootless pasta/8443 with home, credentials and certificate retained; authenticated HTTPS and actual Chromium/CDP rendering passed.
- Rocky Linux 10.1 / Podman 6.1.4: install, repeated install, stop/start, update with home/password preservation, and reset with password retention/certificate regeneration passed. Browser rendering was checked after the lifecycle tests.
- Both hosts: rootless runtime confirmed, SELinux enforcing, restart policy `no`, active/persistent RFC1918 firewall rules, allowed private-source and rejected non-private-source requests verified using a disposable network namespace. Legacy port443 rules removed after acceptance.
- Rootless update testing exposed incomplete private-home relabeling by Podman. The manager now applies the exact owned container's MountLabel recursively through `podman unshare chcon` before each stopped-container start, including replacement and rollback. It does not relabel a running desktop or disable SELinux.
- 25 local unit tests and Bash/ShellCheck checks passed. Automated recovery paths are covered locally; an actual SELinux-related failed update and recovery were also exercised on the Rocky10 host.
- No host reboot was performed in this revision. Linger is enabled for the user manager, but no desktop boot unit is installed and the container has `--restart=no`. Clipboard/file-transfer roundtrips and GPU passthrough are not part of this acceptance.

## Rootless host integration

- The host CLI still requires root for packages, firewall, protected metadata and account setup.
- The dedicated account has a locked/default-disabled password and `/sbin/nologin`; it is not an additional SSH login.
- Its home is `DATA_DIR/runtime`, mode 0700. Images, writable container layers and runtime settings remain outside the resettable desktop home.
- BASE/build ancestors are traversable where required; protected control files remain root-owned mode 0600.
- When a root-owned ancestor such as `/srv/docker` is not traversable, the installer grants only execute permission to the dedicated user through a named ACL. It does not grant directory listing/write access or open it to everyone. ACL changes are a host-side effect and persist independently of reset. Original ACLs are saved under `backups/ancestor-acl-*.acl`; masked existing entries trigger an abort for administrator review rather than silently widening access. ACL mask bits may change the apparent group mode bits without granting the directory group access.
- Linger and the user systemd manager provide a session-independent rootless runtime and cgroup delegation. There is no desktop boot service or automatic image updating.
- Credentials are supplied to the Podman create process through its environment, never secret-bearing command arguments or a world-readable env file. Host root and the runtime account can inspect the container environment; this is not isolation from the operator.
- Do not write root-owned files directly into the desktop home from the host: host UID 0 is outside the rootless mapping. Use the container or the runtime account's `podman unshare` when manipulating mapped files.

## References inspected

These are design references, not scripts executed on the target or copied wholesale:

- Docker installer: https://github.com/docker/docker-install/blob/master/install.sh — explicit defaults, platform checks, dry-run and documented side effects.
- Tailscale installer: https://github.com/tailscale/tailscale/blob/main/scripts/installer.sh — OS/package-manager dispatch and upfront failure handling.
- Podman rename: https://docs.podman.io/en/latest/markdown/podman-rename.1.html — preserving the original container during replacement.
- LinuxServer Webtop: https://docs.linuxserver.io/images/docker-webtop/ — image, volumes and security boundaries.

## License

GNU General Public License version 3 (`GPL-3.0-only`). See the repository [LICENSE](../../LICENSE).
