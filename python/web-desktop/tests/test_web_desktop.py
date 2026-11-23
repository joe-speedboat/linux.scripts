# SPDX-License-Identifier: GPL-3.0-only
import os
import pathlib
import subprocess
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'web-desktop.sh'


def load(edits=None):
    text = SCRIPT.read_text()
    for old, new in (edits or {}).items():
        assert old in text
        text = text.replace(old, new, 1)
    header = text.split('exec python3', 1)[0]
    header = '\n'.join(line for line in header.splitlines() if not line.startswith('WEB_DESKTOP_SCRIPT_PATH='))
    data = subprocess.check_output(['bash', '-c', header + '\nenv -0'])
    env = dict(x.split('=', 1) for x in data.decode().split('\0') if x)
    namespace = {'__name__': 'manager_test'}
    with patch.dict(os.environ, env, clear=True):
        exec(compile(text.split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0], str(SCRIPT), 'exec'), namespace)
    return namespace


class ManagerContract(unittest.TestCase):
    def test_journal_reader_is_scoped_to_exact_container(self):
        ns = load()
        self.assertIn('journal_arguments', ns)
        command = ns['journal_arguments']('a' * 64, 12, True)
        self.assertEqual(command[0], 'journalctl')
        self.assertIn('CONTAINER_ID_FULL=' + 'a' * 64, command)
        self.assertIn('--follow', command)
        self.assertIn('12', command)
        self.assertNotIn('--follow', ns['journal_arguments']('b' * 64, 0, False))

    def test_typed_defaults_and_package_lists(self):
        self.assertTrue(SCRIPT.exists(), 'Structured manager implementation is missing')
        ns = load()
        cfg = ns['default_settings']()
        self.assertEqual(cfg['username'], 'webdesktop')
        self.assertEqual(cfg['upstream_image'], 'lscr.io/linuxserver/webtop:alpine-xfce')
        self.assertEqual(cfg['desktop_packages'], ['openssh-client'])
        self.assertEqual(cfg['host_packages'], ['podman', 'passt', 'acl'])
        missing_acl = dict(cfg, host_packages=['podman', 'passt'])
        with self.assertRaisesRegex(RuntimeError, 'acl'):
            ns['validate_settings'](missing_acl)
        self.assertEqual(cfg['port'], 8443)
        self.assertEqual(cfg['runtime_user'], 'webdesktop')
        self.assertEqual(cfg['runtime_mode'], 'rootless-pasta')
        self.assertEqual(ns['validate_settings'](cfg), cfg)
        cfg['surprise'] = True
        with self.assertRaises(RuntimeError):
            ns['validate_settings'](cfg)


    def test_build_and_container_render_use_the_saved_configuration(self):
        ns = load()
        self.assertTrue('render_containerfile' in ns, 'Build renderer is missing')
        cfg = ns['default_settings']()
        cfg.update(port=8443, memory='1500m', desktop_packages=['firefox', 'openssh-client', 'curl'])
        dockerfile = ns['render_containerfile'](cfg, 'example.invalid/base@sha256:' + 'a' * 64)
        self.assertIn('apk add --no-cache firefox openssh-client curl', dockerfile)
        args = ns['container_arguments'](cfg, 'localhost/web-desktop:qa')
        self.assertIn('--restart=no', args)
        self.assertIn(':8443:3001', ' '.join(args))
        self.assertIn('1500m', args)
        self.assertNotIn('--privileged', args)
        cfg.update(desktop_packages=[], glycin_compat=False)
        dockerfile = ns['render_containerfile'](cfg, 'example.invalid/base@sha256:' + 'a' * 64)
        self.assertNotIn('apk add', dockerfile)
        self.assertNotIn('bwrap', dockerfile)

    def test_command_specific_help_and_safe_option_parsing(self):
        for command in ('install', 'start', 'stop', 'update', 'reset', 'status', 'logs'):
            result = subprocess.run(['bash', str(SCRIPT), command, '--help'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual('--yes' in result.stdout, command == 'reset')
            self.assertEqual('--dry-run' in result.stdout, command in ('install', 'update'))
        for args in (['start', '--yes'], ['update', '--yes'], ['reset', '--dry-run']):
            result = subprocess.run(['bash', str(SCRIPT), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)

    def test_existing_install_plan_describes_reuse_not_reconfiguration(self):
        import contextlib
        import io
        ns = load()
        manager = ns['Manager']()
        active = ns['default_settings']()
        active['bind_address'] = '192.0.2.10'
        active['port'] = 443
        manager.state = {'phase': 'ready', 'applied': active}
        manager.config = dict(active, port=8443)
        manager.resolve_address = lambda config, explicit=None: config
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            manager.plan('install', None)
        self.assertIn('https://192.0.2.10/', out.getvalue())
        self.assertIn('No build', out.getvalue())
        self.assertNotIn(':8443/', out.getvalue())
        with self.assertRaises(RuntimeError):
            manager.plan('install', '192.0.2.20')

    def test_platform_allowlist_accepts_only_supported_enterprise_linux(self):
        ns = load()
        for distro in ('rocky', 'almalinux', 'rhel'):
            with self.subTest(distro=distro):
                release = f'ID="{distro}"\nVERSION_ID="9.7"\n'
                with patch('pathlib.Path.read_text', return_value=release), patch('os.geteuid', return_value=0):
                    ns['check_platform']()
        for distro, version in (('debian', '12'), ('ubuntu', '24.04'), ('fedora', '44'), ('rocky', '8.10')):
            with self.subTest(distro=distro, version=version):
                release = f'ID={distro}\nVERSION_ID="{version}"\n'
                with patch('pathlib.Path.read_text', return_value=release), patch('os.geteuid', return_value=0):
                    with self.assertRaisesRegex(RuntimeError, 'Supported host platforms'):
                        ns['check_platform']()

    def test_rocky_10_is_supported(self):
        ns = load()
        with patch('pathlib.Path.read_text', return_value='ID=rocky\nVERSION_ID="10.1"\n'), patch('os.geteuid', return_value=0):
            ns['check_platform']()

    def test_rootless_commands_and_credentials_never_use_secret_arguments(self):
        import types
        ns = load()
        cmd = ns['Commands']()
        cmd.runtime = types.SimpleNamespace(pw_name='webdesktop', pw_uid=1234,
                                            pw_dir='/srv/docker/web-desktop/runtime')
        credentials = {'CUSTOM_USER': 'desktop', 'PASSWORD': 'test-only-secret'}
        cfg = ns['default_settings']()
        args = ns['container_arguments'](cfg, 'localhost/web-desktop:test')
        self.assertEqual(args[args.index('--network') + 1], 'pasta')
        self.assertNotIn('--env-file', args)
        with patch.dict(ns, read_credentials=lambda: credentials), patch('subprocess.run') as run:
            run.return_value.returncode = 0
            cmd.run(*args)
            actual = run.call_args.args[0]
            self.assertEqual(actual[:4], ['runuser', '-u', 'webdesktop', '--'])
            self.assertIn('HOME=/srv/docker/web-desktop/runtime', actual)
            self.assertIn('XDG_RUNTIME_DIR=/run/user/1234', actual)
            self.assertNotIn('test-only-secret', ' '.join(actual))
            self.assertEqual(run.call_args.kwargs['env']['PASSWORD'], credentials['PASSWORD'])
            cmd.run('dnf', 'install', '-y', 'passt')
            self.assertEqual(run.call_args.args[0], ('dnf', 'install', '-y', 'passt'))
        with self.assertRaisesRegex(RuntimeError, 'runtime'):
            ns['Commands']().run('podman', 'info')

    def test_old_rootful_metadata_is_rejected_before_podman(self):
        import json
        ns = load()
        old = ns['default_settings']()
        old.pop('runtime_mode')
        old.pop('runtime_user')
        with patch('pathlib.Path.exists', return_value=True), patch.dict(ns, secure_read=lambda p: json.dumps(old)):
            with self.assertRaisesRegex(RuntimeError, 'rootful.*migration'):
                ns['Manager']().load()

    def test_runtime_identity_rejects_unrelated_user(self):
        import types
        ns = load()
        user = types.SimpleNamespace(pw_uid=1234, pw_gid=1234, pw_name='webdesktop',
                                     pw_dir='/home/webdesktop', pw_gecos='', pw_shell='/bin/bash')
        with patch('pwd.getpwnam', return_value=user):
            with self.assertRaisesRegex(RuntimeError, 'Unrelated runtime user'):
                ns['Manager']().runtime_identity(ns['default_settings']())

    def test_home_ownership_uses_rootless_namespace_not_host_uid_1000(self):
        import types
        ns = load()
        manager = ns['Manager']()
        manager.cmd.runtime = types.SimpleNamespace(pw_uid=1234, pw_gid=1234)
        with patch('os.chown') as chown, patch.object(manager.cmd, 'run') as run:
            manager.initialize_home(ns['default_settings']())
            chown.assert_called_once_with(ns['HOME'], 1234, 1234)
            run.assert_called_once_with('podman', 'unshare', 'chown', '1000:1000', str(ns['HOME']))

    def test_install_bootstraps_before_any_podman_and_maps_new_home(self):
        from unittest.mock import Mock
        ns = load()
        manager = ns['Manager']()
        cfg = ns['default_settings']()
        cfg['bind_address'] = '192.0.2.10'
        manager.resolve_address = lambda *args: cfg
        manager.check_port = Mock()
        manager.rule_plan = Mock()
        events = []
        manager.cmd.run = lambda *args, **kw: events.append(args[0])
        manager.cmd.log = Mock()
        manager.setup_runtime = lambda *args, **kw: events.append('runtime')
        manager.inspect = lambda *args: events.append('inspect')
        manager.initialize_home = lambda *args: events.append('map-home')
        manager.build = lambda *args: ('image', 'digest')
        manager.activate = Mock()
        manager.install_cli = Mock()
        manager.announce_password = Mock()
        with patch('pathlib.Path.exists', return_value=False), patch('pathlib.Path.mkdir'), patch('pathlib.Path.iterdir', return_value=iter([])), patch('os.chown'), patch.dict(ns, atomic=Mock(), save_json=Mock(), read_credentials=lambda: {'CUSTOM_USER': 'webdesktop', 'PASSWORD': 'fixture'}):
            manager.install(None)
        self.assertEqual(events[:4], ['dnf', 'runtime', 'inspect', 'map-home'])

    def test_install_maps_existing_empty_home_but_preserves_populated_home(self):
        from unittest.mock import Mock
        ns = load()
        for populated in (False, True):
            manager = ns['Manager']()
            cfg = ns['default_settings']()
            cfg['bind_address'] = '192.0.2.10'
            manager.state = {'schema': 1, 'manager': ns['OWNER'], 'phase': 'prepared', 'owned_rules': [], 'password_pending': False}
            manager.config = cfg
            for name in ('check_port', 'rule_plan', 'setup_runtime', 'initialize_home', 'activate', 'install_cli', 'announce_password'):
                setattr(manager, name, Mock())
            manager.resolve_address = lambda *args: cfg
            manager.inspect = lambda *args: None
            manager.build = lambda *args: ('image', 'digest')
            manager.cmd.run = Mock()
            manager.cmd.log = Mock()
            with patch('pathlib.Path.exists', return_value=True), patch('pathlib.Path.iterdir', return_value=iter([pathlib.Path('file')] if populated else [])), patch.dict(ns, save_json=Mock(), read_credentials=lambda: {'CUSTOM_USER': 'webdesktop', 'PASSWORD': 'fixture'}):
                manager.install(None)
            self.assertEqual(manager.initialize_home.call_count, 0 if populated else 1)

    def test_runtime_bootstrap_creates_account_and_linger_not_desktop_service(self):
        import types
        ns = load()
        manager = ns['Manager']()
        cfg = ns['default_settings']()
        user = types.SimpleNamespace(pw_uid=1234, pw_gid=1234, pw_name='webdesktop',
                                     pw_dir=str(ns['RUNTIME_HOME']), pw_gecos=ns['OWNER'], pw_shell='/sbin/nologin')
        with patch('pwd.getpwnam', side_effect=[KeyError(), user]), patch('pathlib.Path.exists', return_value=False), patch('pathlib.Path.mkdir'), patch('os.chown'), patch('pathlib.Path.read_text', return_value='webdesktop:100000:65536\n'), patch.object(manager.cmd, 'run') as run:
            run.return_value.returncode = 0
            manager.setup_runtime(cfg, create=True)
        calls = [c.args for c in run.call_args_list]
        self.assertEqual(calls[0][0], 'useradd')
        self.assertIn(('loginctl', 'enable-linger', 'webdesktop'), calls)
        self.assertIn(('systemctl', 'start', 'user@1234.service'), calls)
        self.assertFalse(any('web-desktop.service' in c for c in calls))
        self.assertEqual(manager.cmd.runtime, user)

    def test_runtime_repairs_only_blocked_root_owned_ancestors(self):
        import types
        ns = load()
        manager = ns['Manager']()
        user = types.SimpleNamespace(pw_uid=1234, pw_gid=1234, pw_name='webdesktop')
        manager.runtime_identity = lambda cfg: user
        accessible = {'/', '/srv'}
        events = []
        def run(*args, **kwargs):
            events.append(args)
            if args[0] == 'runuser':
                self.assertEqual(args[:6], ('runuser', '-u', 'webdesktop', '--', 'test', '-x'))
                return types.SimpleNamespace(returncode=0 if args[-1] in accessible else 1)
            if args[0] == 'getfacl':
                return types.SimpleNamespace(returncode=0, stdout='original ACL\n')
            if args[0] == 'setfacl':
                self.assertEqual(events[-2][0], 'backup')
                self.assertEqual(args, ('setfacl', '-m', 'u:1234:--x', '--', '/srv/docker'))
                accessible.add(args[-1])
            return types.SimpleNamespace(returncode=0)
        manager.cmd.run = run
        def backup(path, text):
            events.append(('backup', path, text))
            self.assertEqual(path.parent, ns['BASE'] / 'backups')
            self.assertEqual(text, 'original ACL\n')
        with patch('pathlib.Path.exists', return_value=True), patch('pathlib.Path.stat', return_value=types.SimpleNamespace(st_uid=0)), patch('pathlib.Path.read_text', return_value='webdesktop:100000:65536\n'), patch('os.chmod') as chmod, patch.dict(ns, atomic=backup):
            manager.setup_runtime(ns['default_settings']())
            manager.setup_runtime(ns['default_settings']())
        changes = [args for args in events if args[0] == 'setfacl']
        self.assertEqual(len(changes), 1)
        self.assertEqual([args[-1] for args in events if args[0] == 'runuser'][:4], ['/', '/srv', '/srv/docker', '/srv/docker'])
        chmod.assert_not_called()

    def test_ancestor_acl_failures_stop_bootstrap(self):
        from unittest.mock import Mock
        import types
        for owner, probe_codes, failure in ((1000, [1], 'not root-owned'),
                                             (0, [2], 'Cannot test'),
                                             (0, [1], 'masked ACL'),
                                             (0, [1, 1], 'still cannot traverse')):
            with self.subTest(failure=failure):
                ns = load()
                manager = ns['Manager']()
                manager.runtime_identity = lambda cfg: types.SimpleNamespace(pw_uid=1234, pw_name='webdesktop')
                codes = iter(probe_codes)
                def run(*args, **kwargs):
                    return types.SimpleNamespace(returncode=next(codes) if args[0] == 'runuser' else 0,
                                                 stdout='user:other:rwx\t#effective:r-x\n' if failure == 'masked ACL' else 'ACL\n')
                manager.cmd.run = Mock(side_effect=run)
                manager.cmd.log = Mock()
                with patch('pathlib.Path.stat', return_value=types.SimpleNamespace(st_uid=owner)), patch.dict(ns, atomic=Mock()):
                    with self.assertRaisesRegex(RuntimeError, failure):
                        manager.setup_runtime(ns['default_settings']())
                calls = [call.args[0] for call in manager.cmd.run.call_args_list]
                self.assertNotIn('loginctl', calls)
                if len(probe_codes) == 1:
                    self.assertNotIn('setfacl', calls)


    def test_rootless_processes_do_not_inherit_root_working_directory(self):
        import types
        ns = load()
        cmd = ns['Commands']()
        cmd.runtime = types.SimpleNamespace(pw_name='webdesktop', pw_uid=1234, pw_dir=str(ns['RUNTIME_HOME']))
        with patch('subprocess.run') as run:
            run.return_value.returncode = 0
            cmd.run('podman', 'info')
            self.assertEqual(run.call_args.kwargs.get('cwd'), '/')
        with patch('subprocess.Popen') as popen:
            popen.return_value.wait.return_value = 0
            cmd.run('podman', 'pull', 'example.invalid/image', stream=True)
            self.assertEqual(popen.call_args.kwargs.get('cwd'), '/')
        manager = ns['Manager']()
        manager.load = lambda: True
        manager.state = {'phase': 'ready', 'applied': ns['default_settings']()}
        manager.runtime_identity = lambda cfg: cmd.runtime
        manager.inspect = lambda name: {'Id': 'a' * 64}
        args = types.SimpleNamespace(command='logs', tail=10, follow=True)
        with patch.dict(ns, parse_args=lambda: args, check_platform=lambda: None,
                        check_paths=lambda: None, Manager=lambda: manager), patch('subprocess.call', return_value=0) as call:
            self.assertEqual(ns['main'](), 0)
            self.assertEqual(call.call_args.kwargs.get('cwd'), '/')

    def test_start_relabels_private_home_in_rootless_namespace_before_start(self):
        import json
        import types
        from unittest.mock import Mock
        ns = load()
        manager = ns['Manager']()
        cfg = ns['default_settings']()
        manager.config = cfg
        manager.state = {'phase': 'ready', 'applied': cfg, 'image': 'localhost/web-desktop:test'}
        manager.interface = Mock()
        manager.check_port = Mock()
        manager.ready = Mock()
        manager.cmd.runtime = types.SimpleNamespace(pw_name='webdesktop', pw_uid=1234, pw_dir=str(ns['RUNTIME_HOME']))
        label = 'system_u:object_r:container_file_t:s0:c123,c456'
        info = {'Config': {'Labels': {ns['OWNER']: 'true'}},
                'Mounts': [{'Source': str(ns['HOME']), 'Destination': '/config'}],
                'State': {'Running': False}, 'MountLabel': label}
        commands = []
        def run(command, **kwargs):
            args = command[command.index('podman'):]
            commands.append(args)
            self.assertEqual(command[:4], ['runuser', '-u', 'webdesktop', '--'])
            self.assertNotIn('PASSWORD', kwargs['env'])
            return subprocess.CompletedProcess(command, 0, json.dumps([info]) if args[1] == 'inspect' else '', '')
        with patch('subprocess.run', side_effect=run):
            manager.start()
        self.assertEqual(commands[-2:], [
            ['podman', 'unshare', 'chcon', '-R', label, str(ns['HOME'])],
            ['podman', 'start', cfg['container_name']]])
        manager.ready.assert_called_once_with(cfg)

    def test_replacement_and_rollback_relabel_each_containers_exact_mcs(self):
        import copy
        import json
        from unittest.mock import Mock
        ns = load()
        manager = ns['Manager']()
        cfg = ns['default_settings']()
        name = cfg['container_name']
        old_label = 'system_u:object_r:container_file_t:s0:c1,c2'
        new_label = 'system_u:object_r:container_file_t:s0:c3,c4'
        old = {'Id': 'old', 'State': {'Running': True}, 'MountLabel': old_label,
               'Config': {'Labels': {ns['OWNER']: 'true'}},
               'Mounts': [{'Source': str(ns['HOME']), 'Destination': '/config'}]}
        containers = {name: copy.deepcopy(old)}
        manager.state = {'phase': 'ready', 'applied': cfg, 'owned_rules': []}
        manager.rule_plan = lambda cfg: []
        manager.cmd.log = Mock()
        manager.ready = Mock(side_effect=[RuntimeError('candidate not ready'), None])
        events = []
        def run(*args, **kwargs):
            events.append(args)
            operation = args[1]
            if operation == 'container':
                return subprocess.CompletedProcess(args, 0 if args[-1] in containers else 1, '', '')
            if operation == 'inspect':
                return subprocess.CompletedProcess(args, 0, json.dumps([containers[args[-1]]]), '')
            if operation == 'rename':
                containers[args[-1]] = containers.pop(args[-2])
            elif operation == 'stop':
                containers[args[-1]]['State']['Running'] = False
            elif operation == 'rm':
                containers.pop(args[-1])
            elif operation == 'create':
                containers[name] = copy.deepcopy(old)
                containers[name].update(Id='new', MountLabel=new_label, State={'Running': False})
            return subprocess.CompletedProcess(args, 0, '', '')
        manager.cmd.run = run
        files = {}
        with patch.dict(ns, save_json=lambda path, value: files.update({path: copy.deepcopy(value)}),
                        secure_read=lambda path: json.dumps(files[path])), \
                patch('pathlib.Path.exists', side_effect=lambda: True), patch('pathlib.Path.unlink'):
            with self.assertRaisesRegex(RuntimeError, 'candidate not ready'):
                manager.activate(cfg, 'localhost/web-desktop:new', 'digest', start=True)
        transitions = [args for args in events if args[1] in ('unshare', 'start')]
        self.assertEqual(transitions, [
            ('podman', 'unshare', 'chcon', '-R', new_label, str(ns['HOME'])),
            ('podman', 'start', name),
            ('podman', 'unshare', 'chcon', '-R', old_label, str(ns['HOME'])),
            ('podman', 'start', name)])
        self.assertEqual(containers[name]['Id'], 'old')

    def test_already_running_container_is_not_relabelled_or_restarted(self):
        from unittest.mock import Mock
        ns = load()
        manager = ns['Manager']()
        manager.inspect = Mock(return_value={'State': {'Running': True}, 'MountLabel': 'private-label'})
        manager.cmd.run = Mock()
        manager.start_container('web-desktop')
        manager.cmd.run.assert_not_called()

    def test_start_without_selinux_skips_relabel(self):
        from unittest.mock import Mock
        ns = load()
        for label in ('', None):
            with self.subTest(label=label):
                manager = ns['Manager']()
                manager.inspect = Mock(return_value={'State': {'Running': False}, 'MountLabel': label})
                manager.cmd.run = Mock()
                manager.start_container('web-desktop')
                manager.cmd.run.assert_called_once_with('podman', 'start', 'web-desktop')

    def test_relabel_failure_prevents_start_without_chown_or_bypass(self):
        from unittest.mock import Mock
        ns = load()
        manager = ns['Manager']()
        manager.inspect = Mock(return_value={'State': {'Running': False}, 'MountLabel': 'private-label'})
        manager.cmd.run = Mock(side_effect=RuntimeError('Operation not permitted'))
        with self.assertRaisesRegex(RuntimeError, 'Operation not permitted'):
            manager.start_container('web-desktop')
        manager.cmd.run.assert_called_once_with('podman', 'unshare', 'chcon', '-R', 'private-label', str(ns['HOME']))

    def test_relabel_rejects_missing_unowned_or_unexpected_mount_containers(self):
        import json
        from unittest.mock import Mock
        ns = load()
        for info, error in ((None, 'missing'), ({'Config': {'Labels': {}}}, 'Unrelated'),
                            ({'Config': {'Labels': {ns['OWNER']: 'true'}}, 'Mounts': []}, 'unexpected home')):
            with self.subTest(error=error):
                manager = ns['Manager']()
                manager.cmd.run = Mock(return_value=subprocess.CompletedProcess([], 1 if info is None else 0, '', ''))
                manager.cmd.text = Mock(return_value=json.dumps([info]))
                with self.assertRaisesRegex(RuntimeError, error):
                    manager.start_container('web-desktop')
                manager.cmd.run.assert_called_once_with('podman', 'container', 'exists', 'web-desktop', check=False)

    def test_stopped_replacement_and_recovery_never_start_or_relabel(self):
        import json
        from unittest.mock import Mock
        ns = load()
        cfg = ns['default_settings']()
        old = {'Id': 'old', 'State': {'Running': False}}
        manager = ns['Manager']()
        manager.state = {'phase': 'ready', 'applied': cfg, 'owned_rules': []}
        manager.inspect = Mock(return_value=old)
        manager.rule_plan = Mock(return_value=[])
        manager.cmd.run = Mock()
        manager.start_container = Mock()
        manager.finish_transaction = Mock()
        with patch.dict(ns, save_json=Mock()):
            manager.activate(cfg, 'localhost/web-desktop:new', 'digest', start=False)
        manager.start_container.assert_not_called()
        for was_running, force_stopped in ((False, False), (True, True)):
            transaction = {'manager': ns['OWNER'], 'phase': 'prepared', 'previous': manager.state,
                           'name': cfg['container_name'], 'rollback_name': 'rollback',
                           'old_id': 'old', 'was_running': was_running, 'plan': []}
            manager.inspect = Mock(side_effect=[old, None])
            manager.cmd.run.reset_mock()
            manager.cmd.log = Mock()
            with patch.dict(ns, secure_read=lambda path: json.dumps(transaction), save_json=Mock()), \
                    patch('pathlib.Path.exists', return_value=True), patch('pathlib.Path.unlink'):
                manager.recover(force_stopped=force_stopped)
            manager.start_container.assert_not_called()
            manager.cmd.run.assert_not_called()

    def test_debian_install_is_rejected_before_paths_or_manager_are_touched(self):
        import types
        ns = load()
        def forbidden():
            self.fail('Unsupported OS reached a filesystem/platform action')
        replacements = {'parse_args': lambda: types.SimpleNamespace(command='install'),
                        'check_paths': forbidden, 'Manager': forbidden}
        with patch.dict(ns, replacements), patch('pathlib.Path.read_text', return_value='ID=debian\nVERSION_ID="12"\n'):
            with self.assertRaisesRegex(RuntimeError, 'Supported host platforms'):
                ns['main']()

if __name__ == '__main__':
    unittest.main()
