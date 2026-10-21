"""by3's make_mod_manifest.py: the interface it offers fits by3 (issue #144).

The script was a copy of the Tears of the Kingdom one and still carried its interface: TOTK's version names
(v0, v112, v121, v143 - by3 has v120) and TOTK's app layout (the app bundle holds the RomFS - by3's bundle is a
small launcher that names its work folder in Info.plist instead).
"""
import importlib.util
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT/'games/by3/scripts/make_mod_manifest.py'
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location('by3_manifest', SCRIPT)
by3 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(by3)


class Case(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_the_version_is_by3s(self):
        self.assertEqual(by3.VERSIONS, ('v120',))

    def test_the_app_is_read_through_its_work_folder(self):
        work = self.root/'BY3_build'
        (work/'extracted'/'v120'/'romfs').mkdir(parents=True)
        app = self.root/'Bayonetta 3.app'/'Contents'
        app.mkdir(parents=True)
        with (app/'Info.plist').open('wb') as handle:
            plistlib.dump({'BY3WorkFolder': str(work)}, handle)
        self.assertEqual(by3.work_folder(app.parent), str(work))

    def test_an_app_without_a_work_folder_is_reported(self):
        app = self.root/'Bayonetta 3.app'/'Contents'
        app.mkdir(parents=True)
        self.assertIsNone(by3.work_folder(app.parent))

    def test_the_command_line_rejects_the_totk_versions(self):
        mod = self.root/'m'
        mod.mkdir()
        done = subprocess.run([sys.executable, str(SCRIPT), str(mod), '--version', 'v143', '--romfs', str(mod)],
                              capture_output=True, text=True)
        self.assertNotEqual(done.returncode, 0)
        self.assertIn('v120', done.stderr)

    def test_the_command_line_names_by3s_way(self):
        mod = self.root/'m'
        mod.mkdir()
        done = subprocess.run([sys.executable, str(SCRIPT), str(mod), '--help'], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('Bayonetta 3.app', done.stdout)
        self.assertIn('v120', done.stdout)
        self.assertNotIn('Tears of the Kingdom', done.stdout)


if __name__ == '__main__':
    unittest.main()
