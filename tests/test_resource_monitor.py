from importlib.machinery import SourceFileLoader
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
monitor = SourceFileLoader("spectrum_resource_monitor", str(ROOT / "scripts" / "resource-monitor")).load_module()


class ResourceMonitorTests(unittest.TestCase):
    def test_memory_levels_include_swap_pressure(self):
        healthy = {"MemTotal": 16_000, "MemAvailable": 8_000, "SwapTotal": 4_000, "SwapFree": 3_000}
        warning = {"MemTotal": 16_000, "MemAvailable": 2_000, "SwapTotal": 4_000, "SwapFree": 2_000}
        critical = {"MemTotal": 16_000, "MemAvailable": 1_000, "SwapTotal": 4_000, "SwapFree": 0}

        self.assertEqual(monitor.memory_level(healthy)[0], 0)
        self.assertEqual(monitor.memory_level(warning)[0], 1)
        self.assertEqual(monitor.memory_level(critical)[0], 2)

    def test_nearly_full_swap_warns_before_ram_is_critical(self):
        values = {"MemTotal": 16_000, "MemAvailable": 3_500, "SwapTotal": 4_000, "SwapFree": 400}
        level, _available, swap = monitor.memory_level(values)

        self.assertEqual(level, 1)
        self.assertEqual(swap, 90)

    def test_full_swap_does_not_warn_after_ram_recovers(self):
        values = {"MemTotal": 16_000, "MemAvailable": 8_000, "SwapTotal": 4_000, "SwapFree": 0}

        self.assertEqual(monitor.memory_level(values)[0], 0)

    def test_cpu_percent_uses_busy_delta(self):
        self.assertEqual(monitor.cpu_percent((1_000, 400), (1_200, 450)), 75)

    def test_disk_levels_use_percent_and_absolute_floor(self):
        self.assertEqual(monitor.disk_level(100 * monitor.GIB, 20 * monitor.GIB)[0], 0)
        self.assertEqual(monitor.disk_level(100 * monitor.GIB, 9 * monitor.GIB)[0], 1)
        self.assertEqual(monitor.disk_level(100 * monitor.GIB, monitor.GIB)[0], 2)

    def test_largest_processes_are_grouped_by_name(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for pid, name, rss in (("10", "browser", 200), ("11", "browser", 300), ("12", "game", 900)):
                process = root / pid
                process.mkdir()
                (process / "comm").write_text(name, encoding="utf-8")
                (process / "status").write_text(f"Name:\t{name}\nVmRSS:\t{rss} kB\n", encoding="utf-8")

            self.assertEqual(monitor.largest_memory_processes(root, 2), [("game", 900), ("browser", 500)])

    def test_service_is_session_scoped_and_restarts(self):
        content = (ROOT / "system/systemd/user/spectrum-resource-monitor.service").read_text(encoding="utf-8")

        self.assertIn("PartOf=graphical-session.target", content)
        self.assertIn("After=graphical-session.target", content)
        self.assertNotIn("dunst.service", content)
        self.assertIn("ExecStart=/usr/lib/spectrumos/resource-monitor", content)
        self.assertIn("Restart=on-failure", content)


if __name__ == "__main__":
    unittest.main()
