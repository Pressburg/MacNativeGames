"""compile_seed.py (the iOS shader seed): a compiler that fails is reported with its own words, not a pool traceback.

Issue #167: the iOS build died with a concurrent.futures traceback and the compiler's message never reached the
player. The message is the only thing that says what is missing (an iPhoneOS SDK without the Metal toolchain).
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT/'games/totk/ios/tools/compile_seed.py'


class Case(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.seed = self.root/'seed'
        self.seed.mkdir()
        (self.seed/'0000_b.metal').write_text('// a shader\n')
        (self.seed/'seed-manifest.json').write_text(json.dumps({'chain': 'x', 'files': {'0000_b.metal': '0' * 64}}))
        # a fake xcrun that fails the way a missing Metal toolchain does
        self.bin = self.root/'bin'
        self.bin.mkdir()
        self.fake = self.bin/'xcrun'
        self.fake.write_text('#!/bin/sh\necho "xcrun: error: unable to find utility \\"metal\\", not a developer tool or in PATH" >&2\nexit 1\n')
        self.fake.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self):
        env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}')
        return subprocess.run([sys.executable, str(SCRIPT), str(self.seed), 'iphoneos'],
                              capture_output=True, text=True, env=env)

    def test_a_failing_compiler_is_reported_with_its_message(self):
        done = self.run_script()
        self.assertEqual(done.returncode, 1, done.stderr)
        self.assertIn('unable to find utility "metal"', done.stderr)
        self.assertIn('0000_b.metal', done.stderr)                  # the file that failed is named
        self.assertIn('xcodebuild -downloadComponent MetalToolchain', done.stderr)
        self.assertNotIn('Traceback', done.stderr)                  # no pool traceback

    def test_the_manifest_is_left_alone_when_a_file_fails(self):
        before = (self.seed/'seed-manifest.json').read_text()
        self.run_script()
        self.assertEqual((self.seed/'seed-manifest.json').read_text(), before)


if __name__ == '__main__':
    unittest.main()
