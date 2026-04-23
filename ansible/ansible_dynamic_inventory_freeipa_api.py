#!/usr/bin/env python3
##############################################################################################################
# DESC: Pull ansible host and group inventory from freeipa via api
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

"""
Ansible Dynamic Inventory Script for FreeIPA.

Environment variables:
  freeipaserver / FREEIPASERVER
      Comma-separated list of FreeIPA servers, e.g.:
      "localhost,idm01.sun.bitbull.ch"

  freeipauser / FREEIPAUSER
      FreeIPA username

  freeipapassword / FREEIPAPASSWORD
      FreeIPA password

  cert_verify / CERT_VERIFY
      TLS verification policy:
        - true   (default)
        - false
        - /etc/ipa/ca.crt (you can use that on any freeipa clients)

  REQUESTS_CA_BUNDLE / CURL_CA_BUNDLE
      CA bundle path, used when CERT_VERIFY is unset or true

  freeipaconnecttimeout / FREEIPA_CONNECT_TIMEOUT
      Connect timeout in seconds (default: 5)

  freeipareadtimeout / FREEIPA_READ_TIMEOUT
      Read timeout in seconds (default: 30)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import time
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple, Union

import requests
from requests import Session

CACHE_TIME_SEC = 3600
CACHE_FILE = os.path.expanduser("~/.ansible_freeipa.cache")

DEFAULT_CONNECT_TIMEOUT = 5.0
DEFAULT_READ_TIMEOUT = 30.0
DEFAULT_CERT_VERIFY = True

RESERVED_GROUPS = {"_meta", "all", "ungrouped"}


class InventoryError(Exception):
    pass


class ConfigurationError(InventoryError):
    pass


class CacheError(InventoryError):
    pass


class FreeIPATransportError(InventoryError):
    pass


class FreeIPAProtocolError(InventoryError):
    pass


class FreeIPAAPIError(InventoryError):
    pass


def getenv_first(*names: str, default: Optional[str] = None) -> Optional[str]:
    for name in names:
        value = os.getenv(name)
        if value is not None:
            return value
    return default


def parse_timeout(raw: Optional[str], default: float, env_name: str) -> float:
    if raw is None or raw.strip() == "":
        return default
    try:
        value = float(raw)
    except ValueError as exc:
        raise ConfigurationError(f"{env_name} must be numeric, got {raw!r}") from exc
    if value <= 0:
        raise ConfigurationError(f"{env_name} must be > 0, got {raw!r}")
    return value


def parse_cert_verify() -> Union[bool, str]:
    """
    Default CERT_VERIFY to True if not defined.

    Supported values:
      - true / false
      - path to a CA bundle file/directory

    If CERT_VERIFY is unset or true, REQUESTS_CA_BUNDLE / CURL_CA_BUNDLE is used
    when present.
    """
    raw = getenv_first("cert_verify", "CERT_VERIFY")
    env_bundle = os.getenv("REQUESTS_CA_BUNDLE") or os.getenv("CURL_CA_BUNDLE")

    if raw is None or raw.strip() == "":
        if env_bundle:
            bundle = os.path.expanduser(env_bundle)
            if not os.path.exists(bundle):
                raise ConfigurationError(
                    f"CA bundle path from REQUESTS_CA_BUNDLE/CURL_CA_BUNDLE does not exist: {bundle}"
                )
            return bundle
        return DEFAULT_CERT_VERIFY

    value = raw.strip()
    lowered = value.lower()

    if lowered in {"1", "true", "yes", "on"}:
        if env_bundle:
            bundle = os.path.expanduser(env_bundle)
            if not os.path.exists(bundle):
                raise ConfigurationError(
                    f"CA bundle path from REQUESTS_CA_BUNDLE/CURL_CA_BUNDLE does not exist: {bundle}"
                )
            return bundle
        return True

    if lowered in {"0", "false", "no", "off"}:
        return False

    bundle = os.path.expanduser(value)
    if not os.path.exists(bundle):
        raise ConfigurationError(f"CERT_VERIFY CA bundle path does not exist: {bundle}")
    return bundle


def first_value(value: Any) -> Optional[Any]:
    if isinstance(value, list):
        return value[0] if value else None
    return value


def dedupe_preserve_order(items: Iterable[str]) -> List[str]:
    return list(dict.fromkeys(item for item in items if item))


def validate_inventory(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise CacheError("Inventory is not a JSON object")

    if "_meta" not in data or not isinstance(data["_meta"], dict):
        raise CacheError("Inventory missing _meta")

    if "hostvars" not in data["_meta"] or not isinstance(data["_meta"]["hostvars"], dict):
        raise CacheError("Inventory missing _meta.hostvars")

    if "all" not in data or not isinstance(data["all"], dict):
        raise CacheError("Inventory missing all group")

    if "children" not in data["all"] or not isinstance(data["all"]["children"], list):
        raise CacheError("Inventory missing all.children")

    if "ungrouped" not in data or not isinstance(data["ungrouped"], dict):
        raise CacheError("Inventory missing ungrouped group")

    if "hosts" not in data["ungrouped"] or not isinstance(data["ungrouped"]["hosts"], list):
        raise CacheError("Inventory missing ungrouped.hosts")

    return data


def load_cache(path: str, ttl: int) -> Optional[Dict[str, Any]]:
    if not os.path.exists(path):
        return None

    try:
        if time.time() - os.path.getmtime(path) >= ttl:
            return None
    except OSError:
        return None

    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return validate_inventory(data)
    except (OSError, json.JSONDecodeError, CacheError):
        return None


def write_cache_atomic(path: str, data: Dict[str, Any]) -> None:
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)

    rendered = json.dumps(data, indent=4, sort_keys=True)

    fd, tmp_path = tempfile.mkstemp(prefix=".ansible_freeipa.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            try:
                os.fchmod(handle.fileno(), 0o600)
            except AttributeError:
                pass
            handle.write(rendered)
            handle.flush()
            os.fsync(handle.fileno())

        os.replace(tmp_path, path)
        try:
            os.chmod(path, 0o600)
        except OSError:
            pass
    finally:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


class FreeIPAClient:
    def __init__(
        self,
        servers: Sequence[str],
        username: str,
        password: str,
        verify: Union[bool, str],
        connect_timeout: float,
        read_timeout: float,
    ) -> None:
        self.servers = list(servers)
        self.username = username
        self.password = password
        self.verify = verify
        self.connect_timeout = connect_timeout
        self.read_timeout = read_timeout
        self.session: Optional[Session] = None
        self.server: Optional[str] = None

        if verify is False:
            requests.packages.urllib3.disable_warnings()

    @property
    def timeout(self) -> Tuple[float, float]:
        return (self.connect_timeout, self.read_timeout)

    def _build_session(self) -> Session:
        session = requests.Session()
        session.trust_env = True
        session.verify = self.verify
        session.headers.update(
            {"User-Agent": "ansible-dynamic-inventory-freeipa/2.2"}
        )
        return session

    def _transport_exc(self, context: str, exc: Exception) -> FreeIPATransportError:
        return FreeIPATransportError(f"{context}: {exc}")

    def _json_rpc(
        self,
        session: Session,
        server: str,
        method: str,
        args: Optional[Sequence[Any]] = None,
        options: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        payload = {
            "method": method,
            "params": [list(args or []), dict(options or {})],
        }
        headers = {
            "Referer": f"https://{server}/ipa",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        try:
            response = session.post(
                f"https://{server}/ipa/session/json",
                json=payload,
                headers=headers,
                timeout=self.timeout,
            )
        except requests.exceptions.SSLError as exc:
            raise self._transport_exc("TLS verification failed", exc) from exc
        except requests.exceptions.Timeout as exc:
            raise self._transport_exc(f"Timeout during {method}", exc) from exc
        except requests.RequestException as exc:
            raise self._transport_exc(f"Transport failure during {method}", exc) from exc

        if response.status_code != 200:
            raise FreeIPAProtocolError(f"{method} returned HTTP {response.status_code}")

        try:
            data = response.json()
        except ValueError as exc:
            raise FreeIPAProtocolError(f"{method} did not return valid JSON") from exc

        if data.get("error"):
            error = data["error"]
            code = error.get("code", "unknown")
            message = error.get("message") or error.get("name") or str(error)
            raise FreeIPAAPIError(f"{method} API error [{code}]: {message}")

        result = data.get("result")
        if not isinstance(result, dict):
            raise FreeIPAProtocolError(f"{method} returned invalid result payload")

        return result

    def _login(self, server: str) -> Session:
        session = self._build_session()
        url = f"https://{server}/ipa/session/login_password"
        headers = {
            "Referer": f"https://{server}/ipa",
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "text/plain",
        }
        data = {"user": self.username, "password": self.password}

        try:
            response = session.post(
                url,
                headers=headers,
                data=data,
                timeout=self.timeout,
            )
        except requests.exceptions.SSLError as exc:
            raise self._transport_exc("TLS verification failed", exc) from exc
        except requests.exceptions.Timeout as exc:
            raise self._transport_exc("Login timeout", exc) from exc
        except requests.RequestException as exc:
            raise self._transport_exc("Login transport failure", exc) from exc

        if response.status_code != 200:
            raise FreeIPAProtocolError(f"Login returned HTTP {response.status_code}")

        # validate the authenticated JSON endpoint immediately
        self._json_rpc(session, server, "ping")
        return session

    def authenticate(self) -> None:
        errors: List[str] = []

        for server in self.servers:
            try:
                session = self._login(server)
                self.session = session
                self.server = server
                return
            except (FreeIPATransportError, FreeIPAProtocolError) as exc:
                errors.append(f"{server}: {exc}")
                continue
            except FreeIPAAPIError as exc:
                errors.append(f"{server}: {exc}")
                continue

        raise InventoryError(
            "Unable to authenticate to any FreeIPA server. " + "; ".join(errors)
        )

    def call(
        self,
        method: str,
        args: Optional[Sequence[Any]] = None,
        options: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Fail over to the next server on:
          - certificate / SSL errors
          - timeout
          - connection problems
          - non-200 HTTP
          - non-JSON API response

        Do not fail over on FreeIPA JSON-RPC API errors, because that is a valid
        application response rather than a transport/protocol failure.
        """
        if self.session is None or self.server is None:
            self.authenticate()

        ordered_servers: List[str] = []
        if self.server:
            ordered_servers.append(self.server)
        ordered_servers.extend(server for server in self.servers if server != self.server)

        errors: List[str] = []

        for server in ordered_servers:
            session = self.session if server == self.server and self.session else None

            if session is None:
                try:
                    session = self._login(server)
                except (FreeIPATransportError, FreeIPAProtocolError) as exc:
                    errors.append(f"{server}: {exc}")
                    continue
                except FreeIPAAPIError as exc:
                    raise exc

            try:
                result = self._json_rpc(session, server, method, args=args, options=options)
                self.session = session
                self.server = server
                return result
            except (FreeIPATransportError, FreeIPAProtocolError) as exc:
                errors.append(f"{server}: {exc}")
                if session is self.session:
                    self.session = None
                    self.server = None
                continue
            except FreeIPAAPIError:
                raise

        raise InventoryError(f"All FreeIPA servers failed during {method}. " + "; ".join(errors))


def require_complete_find(method: str, result: Dict[str, Any]) -> List[Dict[str, Any]]:
    if result.get("truncated") is True:
        raise InventoryError(
            f"{method} returned a truncated result set. Refusing to emit incomplete inventory."
        )

    items = result.get("result")
    if not isinstance(items, list):
        raise InventoryError(f"{method} returned invalid result list")
    return items


def get_all_hosts(client: FreeIPAClient) -> List[Dict[str, Any]]:
    result = client.call("host_find", options={"sizelimit": 0})
    return require_complete_find("host_find", result)


def get_hostgroups(client: FreeIPAClient) -> List[Dict[str, Any]]:
    result = client.call("hostgroup_find", options={"sizelimit": 0})
    return require_complete_find("hostgroup_find", result)


def get_hosts_in_group(
    client: FreeIPAClient,
    group_name: str,
    visited: Optional[set[str]] = None,
) -> List[str]:
    if visited is None:
        visited = set()

    if group_name in visited:
        return []

    visited.add(group_name)

    result = client.call("hostgroup_show", args=[group_name], options={})
    group_data = result.get("result", {})
    if not isinstance(group_data, dict):
        raise InventoryError(f"hostgroup_show returned invalid data for {group_name!r}")

    hosts = list(group_data.get("member_host", []) or [])
    nested_groups = list(group_data.get("member_hostgroup", []) or [])

    for nested_group in nested_groups:
        hosts.extend(get_hosts_in_group(client, nested_group, visited))

    return dedupe_preserve_order(hosts)


def build_inventory(client: FreeIPAClient) -> Dict[str, Any]:
    all_hosts = get_all_hosts(client)
    hostgroups = get_hostgroups(client)

    inventory: Dict[str, Any] = {
        "_meta": {"hostvars": {}},
        "all": {"children": []},
        "ungrouped": {"hosts": []},
    }

    grouped_hosts: set[str] = set()
    children: List[str] = []

    for group in hostgroups:
        group_name = first_value(group.get("cn"))
        if not group_name:
            continue

        group_name = str(group_name)
        if group_name in RESERVED_GROUPS:
            raise InventoryError(
                f"Hostgroup name {group_name!r} conflicts with reserved Ansible group name"
            )

        hosts = get_hosts_in_group(client, group_name, visited=set())
        hosts = dedupe_preserve_order(hosts)

        inventory[group_name] = {"hosts": hosts}
        children.append(group_name)
        grouped_hosts.update(hosts)

    ungrouped_hosts: List[str] = []
    for host in all_hosts:
        fqdn = first_value(host.get("fqdn"))
        if not fqdn:
            continue
        fqdn = str(fqdn)
        if fqdn not in grouped_hosts:
            ungrouped_hosts.append(fqdn)

    ungrouped_hosts = dedupe_preserve_order(ungrouped_hosts)
    inventory["ungrouped"] = {"hosts": ungrouped_hosts}

    children.append("ungrouped")
    inventory["all"] = {"children": dedupe_preserve_order(children)}

    for host in sorted(grouped_hosts.union(ungrouped_hosts)):
        inventory["_meta"]["hostvars"].setdefault(host, {})

    return inventory


def generate_inventory() -> Dict[str, Any]:
    servers = [
        item.strip()
        for item in (getenv_first("freeipaserver", "FREEIPASERVER", default="") or "").split(",")
        if item.strip()
    ]
    username = getenv_first("freeipauser", "FREEIPAUSER")
    password = getenv_first("freeipapassword", "FREEIPAPASSWORD")

    if not servers or not username or not password:
        raise ConfigurationError(
            "Please set freeipaserver, freeipauser, and freeipapassword"
        )

    cert_verify = parse_cert_verify()
    connect_timeout = parse_timeout(
        getenv_first("freeipaconnecttimeout", "FREEIPA_CONNECT_TIMEOUT"),
        DEFAULT_CONNECT_TIMEOUT,
        "FREEIPA_CONNECT_TIMEOUT",
    )
    read_timeout = parse_timeout(
        getenv_first("freeipareadtimeout", "FREEIPA_READ_TIMEOUT"),
        DEFAULT_READ_TIMEOUT,
        "FREEIPA_READ_TIMEOUT",
    )

    cached = load_cache(CACHE_FILE, CACHE_TIME_SEC)
    if cached is not None:
        return cached

    client = FreeIPAClient(
        servers=servers,
        username=username,
        password=password,
        verify=cert_verify,
        connect_timeout=connect_timeout,
        read_timeout=read_timeout,
    )

    inventory = build_inventory(client)
    validate_inventory(inventory)
    write_cache_atomic(CACHE_FILE, inventory)
    return inventory


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Ansible dynamic inventory from FreeIPA"
    )
    parser.add_argument("--list", action="store_true", help="Output full inventory")
    parser.add_argument("--host", help="Compatibility mode, returns empty JSON")
    args = parser.parse_args()

    try:
        if args.list:
            print(json.dumps(generate_inventory(), indent=4, sort_keys=True))
            return 0

        if args.host is not None:
            print(json.dumps({}))
            return 0

        print(json.dumps({}))
        return 0

    except InventoryError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

