import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MediaControlTests(unittest.TestCase):
    def test_routes_to_shell_and_falls_back_only_when_ipc_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy2(ROOT / "scripts/media-control", root / "media-control")
            (root / "qs").write_text(
                '#!/usr/bin/bash\nprintf "%s\\n" "$*" > "$MEDIA_TEST_IPC"\n'
                'if [[ $MEDIA_TEST_MODE == failure ]]; then exit 1; fi\n'
                'if [[ $MEDIA_TEST_MODE == missing ]]; then printf "Unknown IPC method\\n"; fi\n'
            )
            (root / "media-adapter").write_text(
                '#!/usr/bin/bash\nprintf "%s\\n" "$*" > "$MEDIA_TEST_FALLBACK"\n'
            )
            for name in ("qs", "media-adapter"):
                (root / name).chmod(0o755)
            environment = {**os.environ, "PATH": str(root), "MEDIA_TEST_IPC": str(root / "ipc"),
                           "MEDIA_TEST_FALLBACK": str(root / "fallback")}
            for mode in ("success", "failure", "missing"):
                for action in ("toggle", "next", "previous", "stop"):
                    with self.subTest(mode=mode, action=action):
                        fallback = root / "fallback"
                        fallback.unlink(missing_ok=True)
                        result = subprocess.run(["/usr/bin/bash", str(root / "media-control"), action],
                                                env={**environment, "MEDIA_TEST_MODE": mode})
                        self.assertEqual(result.returncode, 0)
                        self.assertEqual((root / "ipc").read_text().strip(),
                                         "--path /usr/share/spectrumos/spectrum-shell ipc call spectrum-shell mediaKey " + action)
                        self.assertEqual(fallback.exists(), mode != "success")
                        if fallback.exists():
                            self.assertEqual(fallback.read_text().strip(), action)
            for arguments in ([], ["invalid"], ["toggle", "extra"]):
                (root / "ipc").unlink(missing_ok=True)
                result = subprocess.run(["/usr/bin/bash", str(root / "media-control"), *arguments], env=environment)
                self.assertEqual(result.returncode, 2)
                self.assertFalse((root / "ipc").exists())
