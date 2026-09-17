"""GCS delivery regressions: all GCP calls are replaced with a local recorder."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from jinja2 import Environment, FileSystemLoader, StrictUndefined
import hashlib
import yaml

ROOT = Path(__file__).resolve().parents[1]


class GCSDeliveryTests(unittest.TestCase):
    def sync(self, layout, fail=False, remote=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'app'
            source.mkdir()
            if layout:
                audio = source / layout
                audio.mkdir(parents=True)
                (audio / 'rain.mp3').write_bytes(b'test audio')
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            log = root / 'gcs.json'
            aws = bin_dir / 'gsutil'
            aws.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                           'open(os.environ["GCP_TEST_LOG"],"w").write(json.dumps(sys.argv[1:]))\n'
                           'sys.exit(int(os.environ["GCP_TEST_EXIT"]))\n')
            aws.chmod(0o755)
            if remote:
                for args in (['init'], ['add', '.'], ['-c', 'user.name=Test', '-c',
                             'user.email=test@example.invalid', 'commit', '-m', 'fixture']):
                    subprocess.run(['git', '-C', str(source), *args], check=True,
                                   capture_output=True)
                ref = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
                source_arg = source.as_uri()
            else:
                source_arg, ref = str(source), 'main'
            env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'],
                       GCP_TEST_LOG=str(log), GCP_TEST_EXIT='23' if fail else '0', APP_SOURCE_REF=ref)
            result = subprocess.run(['bash', str(ROOT / 'scripts/sync-audio-to-gcs.sh'),
                                     source_arg, 'test-audio-bucket'], env=env,
                                    capture_output=True, text=True, timeout=30)
            return result, json.loads(log.read_text()) if log.exists() else None

    def test_sync_html_audio_without_deletion_or_public_acl(self):
        result, args = self.sync('html/audio')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[:6], ['-q', '-m', 'rsync', '-r', '-e', args[5]])
        self.assertTrue(args[-2].endswith('/html/audio/'))
        self.assertEqual(args[-1], 'gs://test-audio-bucket/audio/')
        self.assertNotIn('-d', args)
        self.assertNotIn('--acl', args)
        self.assertIn('-e', args)

    def test_reject_old_incorrect_audio_path_before_gcs(self):
        result, args = self.sync('audio')
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(args)

    def test_propagate_upload_failure(self):
        result, _ = self.sync('html/audio', fail=True)
        self.assertEqual(result.returncode, 23)

    def test_clone_pinned_source_and_upload(self):
        result, args = self.sync('html/audio', remote=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[-1], 'gs://test-audio-bucket/audio/')

    def test_gcs_uses_upstream_common_image_and_only_audio_scenario_has_bucket(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/build-images.yml').read_text())
        builds = [step for step in workflow['jobs']['build']['steps']
                  if step.get('uses', '').startswith('docker/build-push-action@')]
        self.assertEqual(len(builds), 1)
        self.assertEqual(builds[0]['with']['context'], 'app')
        self.assertNotIn('file', builds[0]['with'])
        self.assertFalse((ROOT / 'docker/gcs.Dockerfile').exists())
        play = yaml.safe_load((ROOT / 'ansible/playbooks/gke-gcs-deploy.yml').read_text())[0]
        self.assertEqual(play['vars']['image_repository'], 'ghcr.io/izanar/gcp-template-kubernetes')
        self.assertEqual(play['vars']['app_repo_url'], 'https://github.com/Izanar/AI_Nginx.git')
        for scenario in ('gce', 'gke-autopilot', 'local-wsl', 'gke-gcs-cdn'):
            source = '\n'.join(path.read_text() for path in (ROOT / 'src' / scenario).glob('*.tf'))
            self.assertEqual('resource "google_storage_bucket"' in source, scenario == 'gke-gcs-cdn')

    def test_rendered_config_routes_audio_and_rolls_out_on_config_change(self):
        env = Environment(loader=FileSystemLoader(str(ROOT / 'ansible/roles/gke_gcs/templates')),
                          undefined=StrictUndefined)
        env.filters['hash'] = lambda value, algorithm: hashlib.new(algorithm, value.encode()).hexdigest()
        values = dict(k8s_namespace='ai-nginx-demo', deployment_name='ai-nginx-app',
                      cdn_domain='audio.example.com',
                      image_repository='ghcr.io/izanar/gcp-template-kubernetes', image_tag='test-sha')
        env.globals['lookup'] = lambda kind, name: env.get_template(name).render(**values)
        config = yaml.safe_load(env.get_template('configmap.yaml.j2').render(**values))
        deployment = yaml.safe_load(env.get_template('deployment.yaml.j2').render(**values))
        self.assertIn('return 302 https://audio.example.com$request_uri;', config['data']['default.conf'])
        pod = deployment['spec']['template']
        self.assertEqual(pod['spec']['containers'][0]['image'], 'ghcr.io/izanar/gcp-template-kubernetes:test-sha')
        self.assertEqual(pod['spec']['volumes'][0]['configMap']['name'], config['metadata']['name'])
        before = pod['metadata']['annotations']['checksum/audio-config']
        values['cdn_domain'] = 'other.example.com'
        changed = yaml.safe_load(env.get_template('deployment.yaml.j2').render(**values))
        self.assertNotEqual(before, changed['spec']['template']['metadata']['annotations']['checksum/audio-config'])


if __name__ == '__main__':
    unittest.main()
