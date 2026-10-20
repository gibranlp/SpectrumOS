import hashlib
import json
import os
import subprocess
import sys
import tempfile
import importlib.machinery
import importlib.util
from pathlib import Path
from datetime import date, timedelta
import sqlite3
import unittest
import uuid
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("questline_adapter", str(ROOT / "scripts/questline-adapter"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
ADAPTER = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(ADAPTER)


class QuestlineAccountTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.addCleanup(self.connection.close)
        self.connection.row_factory = sqlite3.Row
        self.connection.executescript("""
            CREATE TABLE projects (id TEXT, name TEXT, archived INTEGER, completed INTEGER);
            CREATE TABLE campaign_treasury (campaign_id TEXT, currency_code TEXT);
            CREATE TABLE treasury_accounts (id TEXT, campaign_id TEXT, name TEXT, kind TEXT, is_default INTEGER);
            CREATE TABLE ledger_entries (campaign_id TEXT, account_id TEXT, transfer_account_id TEXT,
                                         entry_type TEXT, status TEXT, amount_minor INTEGER);
        """)
        self.campaign = "12345678-1234-5678-1234-567812345678"
        digest = hashlib.sha256(b"treasury-account:" + uuid.UUID(self.campaign).bytes + b"Spending").digest()
        self.spending = str(uuid.UUID(bytes=digest[:16], version=5))
        self.connection.execute("INSERT INTO projects VALUES (?, 'Home', 0, 0)", (self.campaign,))
        self.connection.execute("INSERT INTO campaign_treasury VALUES (?, 'MXN')", (self.campaign,))
        for account_id, name, kind in ((self.spending, "Spending", "Spending"), ("savings", "Savings", "Savings"), ("cash", "Cash", "Cash")):
            self.connection.execute("INSERT INTO treasury_accounts VALUES (?, ?, ?, ?, 1)", (account_id, self.campaign, name, kind))

    def entry(self, kind, status, amount, source=None, destination=None):
        self.connection.execute("INSERT INTO ledger_entries VALUES (?, ?, ?, ?, ?, ?)",
                                (self.campaign, source, destination, kind, status, amount))

    def test_balances_follow_questline_status_and_transfer_rules(self):
        self.entry("Income", "Approved", 10000)
        self.entry("Income", "Paid", 2000)
        self.entry("Expense", "Paid", 1500)
        self.entry("Transfer", "Paid", 3000, self.spending, "savings")
        self.entry("Transfer", "Paid", 500, "savings", "cash")
        for kind in ("Income", "Expense", "Transfer", "Adjustment"):
            for status in ("Planned", "Cancelled"):
                self.entry(kind, status, 90000, self.spending, "savings")
        self.entry("Expense", "Approved", 90000)
        self.entry("Transfer", "Approved", 90000, self.spending, "savings")
        self.entry("Adjustment", "Paid", 90000)
        accounts = ADAPTER.account_balances(self.connection)
        self.assertEqual({a["name"]: a["balance_minor"] for a in accounts},
                         {"Spending": 7500, "Savings": 2500, "Cash": 500})
        self.assertTrue(all(a["currency_code"] == "MXN" and a["campaign"] == "Home" for a in accounts))

    def test_full_history_zero_accounts_and_negative_balances(self):
        for _ in range(40):
            self.entry("Expense", "Paid", 100)
        accounts = ADAPTER.account_balances(self.connection)
        self.assertEqual({a["name"]: a["balance_minor"] for a in accounts},
                         {"Spending": -4000, "Savings": 0, "Cash": 0})
        self.connection.execute("UPDATE projects SET archived = 1")
        self.assertEqual(ADAPTER.account_balances(self.connection), [])

    def test_old_profile_without_account_table(self):
        self.connection.execute("DROP TABLE treasury_accounts")
        self.assertEqual(ADAPTER.account_balances(self.connection), [])

    def test_snapshot_keeps_entries_from_campaigns_outside_recent_thirty(self):
        self.connection.executescript("""
            ALTER TABLE projects ADD COLUMN is_shared INTEGER DEFAULT 0;
            ALTER TABLE ledger_entries ADD COLUMN id TEXT;
            ALTER TABLE ledger_entries ADD COLUMN title TEXT;
            ALTER TABLE ledger_entries ADD COLUMN currency_code TEXT DEFAULT 'MXN';
            ALTER TABLE ledger_entries ADD COLUMN created_at INTEGER;
            CREATE TABLE notes (id TEXT, project_id TEXT, title TEXT, markdown_content TEXT, updated_at INTEGER);
            CREATE TABLE tasks (id TEXT, project_id TEXT, title TEXT, description TEXT, priority TEXT,
                                due_date TEXT, completed INTEGER, parent_task_id TEXT, created_at INTEGER);
            CREATE TABLE zen_tree (stage INTEGER, growth INTEGER, health INTEGER, water_today INTEGER,
                                   last_watered TEXT, total_waterings INTEGER);
            INSERT INTO projects VALUES ('older', 'Older campaign', 0, 0, 0);
        """)
        for index in range(41):
            self.connection.execute("""
                INSERT INTO ledger_entries (id, campaign_id, title, entry_type, status, amount_minor, created_at)
                VALUES (?, ?, 'Income', 'Income', 'Paid', 100, ?)
            """, (str(index), "older" if index == 0 else self.campaign, index))
        snapshot = ADAPTER.snapshot(self.connection)
        self.assertEqual(len(snapshot["entries"]), 41)
        self.assertEqual(snapshot["entries"][-1]["campaign"], "Older campaign")
        self.assertEqual(snapshot["entries"][0]["id"], "40")


class QuestlineChronicleTests(unittest.TestCase):
    def test_daily_logs_keep_campaign_content_author_and_full_history(self):
        with sqlite3.connect(":memory:") as connection:
            connection.row_factory = sqlite3.Row
            connection.executescript("""
                CREATE TABLE projects (id TEXT, name TEXT);
                CREATE TABLE journal_entries (id TEXT, project_id TEXT, entry_date TEXT,
                                             content TEXT, created_at TEXT, author_username TEXT);
                INSERT INTO projects VALUES ('alpha', 'Alpha'), ('beta', 'Beta');
            """)
            for index in range(41):
                connection.execute("INSERT INTO journal_entries VALUES (?, ?, ?, ?, ?, ?)",
                                   (str(index), "beta" if index == 0 else "alpha", "2026-10-19",
                                    "Daily log\nSecond line", f"2026-10-19T12:00:{index:02}", "Igor"))
            items = ADAPTER.chronicles(connection)
            self.assertEqual(len(items), 41)
            self.assertEqual(items[0]["id"], "40")
            self.assertEqual(items[-1]["project_id"], "beta")
            self.assertEqual(items[-1]["campaign"], "Beta")
            self.assertEqual(items[0]["description"], "Daily log\nSecond line")
            self.assertEqual(items[0]["author_username"], "Igor")
            self.assertEqual(items[0]["title"], "2026-10-19")

    def test_older_profiles_without_journals_or_authors_remain_readable(self):
        with sqlite3.connect(":memory:") as connection:
            connection.row_factory = sqlite3.Row
            self.assertEqual(ADAPTER.chronicles(connection), [])
            connection.executescript("""
                CREATE TABLE projects (id TEXT, name TEXT);
                CREATE TABLE journal_entries (id TEXT, project_id TEXT, entry_date TEXT,
                                             content TEXT, created_at TEXT);
                INSERT INTO journal_entries VALUES ('log', 'missing', '2026-10-19', 'Log', '2026-10-19');
            """)
            item = ADAPTER.chronicles(connection)[0]
            self.assertEqual(item["author_username"], "")
            self.assertEqual(item["campaign"], "Unfiled")


class QuestlineBinarySelectionTests(unittest.TestCase):
    def test_all_helpers_prefer_the_user_install_and_fall_back_to_path(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            local = home / ".local/bin/questline"
            packaged = home / "system-bin/questline"
            kitty = packaged.parent / "kitty"
            for binary, marker in ((local, "local"), (packaged, "packaged")):
                binary.parent.mkdir(parents=True, exist_ok=True)
                binary.write_text(
                    f"#!{sys.executable}\nimport json, sys\n"
                    f"if sys.argv[1] == '--help': print('{('shell-action shell-tree' if marker == 'local' else 'legacy help')}')\n"
                    f"else: print(json.dumps({{'source': '{marker}'}}))\n"
                )
                binary.chmod(0o755)
            kitty.write_text(f"#!{sys.executable}\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n")
            kitty.chmod(0o755)
            environment = {**os.environ, "HOME": str(home), "QUESTLINE_STORAGE_DIR": str(home / "profile"),
                           "PATH": str(packaged.parent) + ":/usr/bin"}
            for expected in (local, packaged):
                state = json.loads(subprocess.check_output(
                    [str(ROOT / "scripts/questline-adapter"), "--json"], env=environment, text=True))
                self.assertEqual(state["actions_available"], expected == local)
                self.assertEqual(state["tree_available"], expected == local)
                result = json.loads(subprocess.check_output(
                    [sys.executable, str(ROOT / "scripts/questline-action"), '{"action":"probe"}'], env=environment, text=True))
                self.assertEqual(result["source"], "local" if expected == local else "packaged")
                opened = json.loads(subprocess.check_output(
                    [str(ROOT / "scripts/questline-open")], env=environment, text=True))
                self.assertEqual(opened, ["--class", "questline", "-e", str(expected)])
                local.chmod(0o644)


class QuestlineHeroTests(unittest.TestCase):
    def test_profile_reads_only_public_character_fields_and_statistics(self):
        connection = sqlite3.connect(":memory:")
        self.addCleanup(connection.close)
        connection.row_factory = sqlite3.Row
        connection.executescript("""
            CREATE TABLE users (username TEXT, class TEXT, level INTEGER, xp INTEGER, created_at TEXT,
                                specialization TEXT, private_key TEXT);
            INSERT INTO users VALUES ('Hero', 'Code Warlock', 10, 120, '2026-01-01', 'Bug Hunter', 'secret');
            CREATE TABLE streaks (current_streak INTEGER, best_streak INTEGER);
            INSERT INTO streaks VALUES (3, 12);
            CREATE TABLE notes (id TEXT);
            INSERT INTO notes VALUES ('note');
            CREATE TABLE tasks (completed INTEGER, parent_task_id TEXT);
            INSERT INTO tasks VALUES (1, NULL), (0, NULL), (1, 'parent');
        """)
        hero = ADAPTER.hero_profile(connection)
        self.assertEqual(hero["username"], "Hero")
        self.assertEqual(hero["xp"], 120)
        self.assertEqual(hero["specialization"], "Bug Hunter")
        self.assertEqual(hero["tasks_completed"], 1)
        self.assertEqual(hero["scrolls_written"], 1)
        self.assertEqual(hero["current_streak"], 3)
        self.assertNotIn("private_key", hero)
        connection.execute("ALTER TABLE users DROP COLUMN specialization")
        self.assertIsNone(ADAPTER.hero_profile(connection)["specialization"])
        connection.execute("DELETE FROM users")
        self.assertIsNone(ADAPTER.hero_profile(connection))

    def test_missing_profile_is_supported(self):
        with sqlite3.connect(":memory:") as connection:
            self.assertIsNone(ADAPTER.hero_profile(connection))


class QuestlineSidequestTests(unittest.TestCase):
    def test_daily_progress_and_frequency_are_read_without_hiding_completed_items(self):
        connection = sqlite3.connect(":memory:")
        self.addCleanup(connection.close)
        connection.row_factory = sqlite3.Row
        self.assertEqual(ADAPTER.sidequests(connection), [])
        connection.executescript("""
            CREATE TABLE rituals (id TEXT, name TEXT, description TEXT, frequency TEXT, reward_xp INTEGER, daily_target INTEGER);
            CREATE TABLE ritual_history (ritual_id TEXT, completed_date TEXT, completion_count INTEGER);
            INSERT INTO rituals VALUES ('water', 'Water', 'Drink water', '3x Daily', 20, 3),
                                       ('exercise', 'Exercise', NULL, 'Daily', 10, 1);
        """)
        connection.executemany("INSERT INTO ritual_history VALUES (?, ?, ?)", [
            ("water", date.today().isoformat(), 2),
            ("exercise", date.today().isoformat(), 1),
            ("water", (date.today() - timedelta(days=1)).isoformat(), 3)])
        items = ADAPTER.sidequests(connection)
        self.assertEqual([item["title"] for item in items], ["Exercise", "Water"])
        self.assertEqual([item["completion_count"] for item in items], [1, 2])
        self.assertEqual(items[1]["daily_target"], 3)
        self.assertEqual(items[1]["reward_xp"], 20)
        connection.execute("DROP TABLE ritual_history")
        self.assertTrue(all(item["completion_count"] == 0 for item in ADAPTER.sidequests(connection)))


class QuestlineTreeTests(unittest.TestCase):
    def test_tree_canvas_receives_colored_rows_with_blank_vertical_padding_removed(self):
        rows = [[{"text": "   ", "color": None}],
                [{"text": " *", "color": "#00ff00"}, {"text": "|", "color": None}],
                [{"text": "   ", "color": None}]]
        result = subprocess.CompletedProcess([], 0, json.dumps({"rows": rows}), "")
        tree = {"growth": 42, "stage": 3, "health": 80}
        with patch.object(ADAPTER.subprocess, "run", return_value=result) as run:
            ADAPTER.render_tree("/usr/bin/questline", tree)
        self.assertEqual(tree["bonsai_rows"], [rows[1]])
        request = json.loads(run.call_args.args[0][2])
        self.assertEqual(request, {"rows": 25, "cols": 60, "seed": 42, "stage": 3, "health": 80})

    def test_missing_tree_renderer_does_not_create_canvas_content(self):
        tree = {"growth": 0, "stage": 1, "health": 100}
        with patch.object(ADAPTER.subprocess, "run", side_effect=OSError("unavailable")):
            ADAPTER.render_tree("/usr/bin/questline", tree)
        self.assertNotIn("bonsai_rows", tree)


if __name__ == "__main__":
    unittest.main()
