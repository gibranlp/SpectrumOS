import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "spectrum_mkinitcpio_register_hook", str(ROOT / "scripts" / "mkinitcpio-register-hook")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
REGISTER = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(REGISTER)


SAMPLE = "MODULES=()\nHOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)\n"


class MkinitcpioRegisterHookTests(unittest.TestCase):
    def test_inserts_immediately_before_the_named_hook(self):
        updated = REGISTER.insert_hook(SAMPLE, "spectrumos-restore", "filesystems")
        self.assertIn("block spectrumos-restore filesystems", updated)

    def test_is_idempotent(self):
        once = REGISTER.insert_hook(SAMPLE, "spectrumos-restore", "filesystems")
        self.assertIsNone(REGISTER.insert_hook(once, "spectrumos-restore", "filesystems"))

    def test_refuses_to_guess_when_the_anchor_hook_is_missing(self):
        with self.assertRaises(SystemExit):
            REGISTER.insert_hook(SAMPLE, "spectrumos-restore", "not-a-real-hook")

    def test_refuses_a_config_without_a_single_line_hooks_array(self):
        with self.assertRaises(SystemExit):
            REGISTER.insert_hook("MODULES=()\n", "spectrumos-restore", "filesystems")


if __name__ == "__main__":
    unittest.main()
