from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = (ROOT / 'tests/qml/tst_BreakReminders.qml').read_text()
    source = source.replace('import "../../configs/spectrum-shell" as Shell',
                            f'import Quickshell\nimport "{(ROOT / "configs/spectrum-shell").as_uri()}" as Shell')
    source = source.replace('    name: "BreakReminderCycle"',
                            '    name: "BreakReminderCycle"\n'
                            '    onCompletedChanged: if (completed) { console.log("BREAK_TESTS", qtest_results.passCount, qtest_results.failCount); Qt.quit(); }')
    with tempfile.TemporaryDirectory(prefix='spectrum-break-tests-') as directory:
        path = Path(directory) / 'shell.qml'
        path.write_text(source)
        result = subprocess.run(['qs', '-p', str(path)], capture_output=True, text=True, timeout=20,
                                env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software'})
        output = result.stdout + result.stderr
        print(output)
        if result.returncode or 'BREAK_TESTS 5 0' not in output:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
