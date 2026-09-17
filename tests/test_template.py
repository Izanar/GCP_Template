"""Offline regression checks. Never invoke Terraform apply or contact GCP."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


class TemplateTests(unittest.TestCase):
    def test_gce_has_no_unused_password_secret(self):
        for name in ('main.tf', 'outputs.tf'):
            content = (ROOT / 'src/gce' / name).read_text()
            self.assertNotIn('google_secret_manager_secret', content)
            self.assertNotIn('app_password', content)

    def test_manifest_paths_exist(self):
        path = ROOT / 'ansible/playbooks/gke-deploy.yml'
        play = yaml.safe_load(path.read_text())[0]
        for manifest in play['vars']['kubernetes_manifests']:
            resolved = Path(manifest.replace('{{ playbook_dir }}', str(path.parent)))
            self.assertTrue(resolved.is_file(), resolved)

    def test_service_selects_deployment(self):
        for scenario in ('base', 'local'):
            base = ROOT / 'kubernetes' / scenario
            deployment = yaml.safe_load((base / 'deployment.yaml').read_text())
            service = yaml.safe_load((base / 'service.yaml').read_text())
            self.assertEqual(service['spec']['selector'],
                             deployment['spec']['template']['metadata']['labels'])
            self.assertEqual(service['metadata']['namespace'],
                             deployment['metadata']['namespace'])

    def test_unknown_scenario_stops_before_terraform(self):
        for script in ('deploy.sh', 'destroy.sh'):
            result = subprocess.run(['bash', str(ROOT / 'scripts' / script), '../gce'],
                                    input='', text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)

    def test_local_preflight_stops_before_terraform_without_systemd(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            marker = directory / 'terraform-called'
            for name, body in {
                'ps': 'echo init',
                'terragrunt': f'touch "{marker}"; exit 99',
            }.items():
                executable = directory / name
                executable.write_text('#!/bin/sh\n' + body + '\n')
                executable.chmod(0o755)
            env = dict(os.environ, PATH=str(directory) + ':' + os.environ['PATH'])
            result = subprocess.run(['bash', str(ROOT / 'scripts/deploy.sh'), 'local-wsl'],
                                    env=env, input='', text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Enable systemd', result.stderr)
            self.assertFalse(marker.exists())

    def test_k3s_waits_for_registration_before_readiness(self):
        for mode in ('delayed', 'absent', 'not-ready'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                count = root / 'count'
                ready = root / 'ready'
                tools = {
                    'ps': 'echo systemd',
                    'sudo': 'exit 0',
                    'k3s': 'echo "k3s version v1.31.1+k3s1 (test)"',
                    'sleep': 'exit 0',
                    'kubectl': '''if [ "$1" = get ]; then
n=0
[ ! -f "$COUNT" ] || n=$(cat "$COUNT")
n=$((n + 1))
echo "$n" > "$COUNT"
[ "$MODE" != absent ] || exit 0
[ "$n" -ne 1 ] || exit 1
[ "$n" -gt 2 ] || exit 0
echo node/test
else
[ "$(cat "$COUNT")" -ge 3 ] || exit 99
touch "$READY"
[ "$MODE" != not-ready ] || exit 1
fi''',
                }
                for name, body in tools.items():
                    executable = root / name
                    executable.write_text('#!/bin/sh\n' + body + '\n')
                    executable.chmod(0o755)
                env = dict(os.environ, HOME=directory, COUNT=str(count), READY=str(ready),
                           MODE=mode, PATH=directory + ':' + os.environ['PATH'])
                result = subprocess.run(['bash', str(ROOT / 'scripts/install-wsl-kubernetes.sh')],
                                        env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0 if mode == 'delayed' else 1,
                                 result.stdout + result.stderr)
                self.assertEqual(ready.exists(), mode != 'absent')
                self.assertEqual(int(count.read_text()), 36 if mode == 'absent' else 3)

    def test_workflow_rejects_missing_state_and_unconfirmed_apply(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/deploy.yml').read_text())
        steps = workflow['jobs']['deploy']['steps']
        guard = next(step['run'] for step in steps if step['name'].startswith('Require persistent'))
        for action, confirm, bucket, expected in [
            ('apply', 'false', 'existing', 1),
            ('destroy', 'false', '', 1),
            ('apply', 'true', 'existing', 0),
            ('destroy', 'false', 'existing', 0),
        ]:
            env = dict(os.environ, ACTION=action, CONFIRM_COSTS=confirm,
                       TF_STATE_BUCKET=bucket, GOOGLE_REGION='europe-west1', GOOGLE_PROJECT='test-project')
            result = subprocess.run(['bash', '-e', '-c', guard], env=env,
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
