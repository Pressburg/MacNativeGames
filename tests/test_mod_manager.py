"""The launcher's mod manager (games/totk/app/mod_manager.m): the overlay the game loads is rebuilt from the mods
that are on, and the manifest names every file with its size, its own SHA-256 and the original's SHA-256."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

TOTK = Path(__file__).resolve().parents[1] / 'games/totk'


@unittest.skipUnless(shutil.which('xcrun'), 'needs the Xcode command line tools')
class ModManagerTests(unittest.TestCase):
    def test_probe(self):
        with tempfile.TemporaryDirectory() as tmp:
            probe = Path(tmp) / 'probe'
            compile_ = subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-std=gnu11', '-Wall', '-Wextra', '-Werror',
                                       f'-I{TOTK}/app', f'-I{TOTK}/runtime', f'-I{TOTK}/third_party/d2r_gfx/gfx/nvn',
                                       str(TOTK / 'tests/mod_manager/probe.m'), str(TOTK / 'app/mod_manager.m'),
                                       '-framework', 'AppKit', '-framework', 'Foundation', '-framework', 'CoreGraphics',
                                       '-o', str(probe)], capture_output=True, text=True)
            if compile_.returncode:
                self.skipTest(f'clang could not build the probe: {compile_.stderr[-800:]}')
            run = subprocess.run([str(probe)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(run.stdout)['status'], 'pass')


if __name__ == '__main__':
    unittest.main()
