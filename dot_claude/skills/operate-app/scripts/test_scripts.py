"""Isolated regression tests; no real agents or systemd services are started.

Run with: python3 path/to/scripts/test_scripts.py
"""
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


class ScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="operate-app-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        source = Path(__file__).resolve().parent
        for name in ("install-timer.sh", "run.sh", "common.sh"):
            src = source / name
            if not src.exists():
                src = source / ("executable_" + name)
            dest = self.scripts / name
            shutil.copyfile(src, dest)
            dest.chmod(0o755)
        self.env = dict(os.environ)
        for name in list(self.env):
            if name.startswith("OPERATE_APP_"):
                del self.env[name]
        self.env.update(
            PATH=str(self.bin) + ":" + os.environ["PATH"],
            XDG_CONFIG_HOME=str(self.root / "config"),
            XDG_STATE_HOME=str(self.root / "state"),
            CALL_LOG=str(self.root / "calls"),
            CLAUDE_LOG=str(self.root / "claude.json"),
        )
        self.mock("systemctl", 'printf "%s\\n" "$*" >> "$CALL_LOG"\nexit "${SYSTEMCTL_EXIT:-0}"\n')
        self.mock("loginctl", "echo yes\n")
        self.mock("claude", '''exec python3 -c 'import json, os, sys, time; open(os.environ["CLAUDE_LOG"], "w").write(json.dumps({"args":sys.argv[1:],"cwd":os.getcwd()})); time.sleep(float(os.environ.get("CLAUDE_SLEEP","0"))); sys.exit(int(os.environ.get("CLAUDE_EXIT","0")))' "$@"
''')
        self.repo = self.make_repo("one/app")

    def mock(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def make_repo(self, name):
        repo = self.root / name
        repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        (repo / "docs/ops").mkdir(parents=True)
        (repo / "docs/ops/runbook.md").write_text("# Fixture runbook\n")
        return repo

    def run_script(self, name, *args, **env):
        return subprocess.run(
            [str(self.scripts / name), *map(str, args)],
            env=dict(self.env, **env), capture_output=True, text=True, timeout=8,
        )

    def install(self, *args, repo=None, **env):
        return self.run_script("install-timer.sh", repo or self.repo, *args, **env)

    def run_agent(self, mode="health", repo=None, **env):
        return self.run_script("run.sh", repo or self.repo, mode, **env)

    def state(self):
        return next((self.root / "state/operate-app").iterdir())

    def units(self):
        return self.root / "config/systemd/user"

    def test_dry_uninstall_changes_nothing(self):
        self.assertEqual(self.install().returncode, 0)
        before = {p.name: p.read_bytes() for p in self.units().iterdir()}
        calls = (self.root / "calls").read_bytes()
        result = self.install("--uninstall", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.units().iterdir()})
        self.assertEqual(calls, (self.root / "calls").read_bytes())

    def test_same_basename_different_repositories_have_distinct_units(self):
        other = self.make_repo("two/app")
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(self.install(repo=other).returncode, 0)
        self.assertEqual(len(list(self.units().glob("*.timer"))), 4)
        self.assertEqual(self.run_agent().returncode, 0)
        self.assertEqual(self.run_agent(repo=other).returncode, 0)
        self.assertEqual(len(list((self.root / "state/operate-app").iterdir())), 2)

    def test_symlink_uses_same_units_and_state(self):
        alias = self.root / "alias"
        alias.symlink_to(self.repo, target_is_directory=True)
        self.assertEqual(self.install().stdout, self.install(repo=alias).stdout)
        self.assertEqual(self.run_agent().returncode, 0)
        self.assertEqual(self.run_agent(repo=alias).returncode, 0)
        self.assertEqual(len(list((self.root / "state/operate-app").iterdir())), 1)

    def test_invalid_health_intervals_fail_before_mutation(self):
        for value in ("08", "00", "5", "-1", "18446744073709551619", "oops"):
            with self.subTest(value=value):
                result = self.install("--health", value)
                self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.root / "calls").exists())
        self.assertFalse(self.units().exists())

    def test_valid_calendars(self):
        for value in (0, 1, 2, 3, 4, 6, 8, 12, 24):
            with self.subTest(value=value):
                result = self.install("--health", value, "--dry-run")
                self.assertEqual(result.returncode, 0, result.stderr)
                for calendar in re.findall(r"^OnCalendar=(.*)$", result.stdout, re.M):
                    checked = subprocess.run(["systemd-analyze", "calendar", calendar], capture_output=True, text=True)
                    self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertFalse((self.root / "calls").exists())

    def test_units_pass_systemd_parser_with_spaces(self):
        repo = self.make_repo("space here/app name")
        result = self.install(repo=repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        checked = subprocess.run(["systemd-analyze", "--user", "verify", *map(str, self.units().glob("*"))], capture_output=True, text=True)
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_unsafe_unit_values_are_rejected(self):
        for char in ('"', "'", "$", "%", "\\", "\n"):
            repo = self.make_repo("special" + char + "/app")
            result = self.install("--dry-run", repo=repo)
            self.assertEqual(result.returncode, 2, repr(char))
        result = self.install("--dry-run", PATH=self.env["PATH"] + ":/tmp/unsafe%path")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "calls").exists())

    def test_runs_have_private_separate_transcripts_and_use_checkout(self):
        for _ in range(2):
            result = self.run_agent()
            self.assertEqual(result.returncode, 0, result.stderr)
        logs = list((self.state() / "runs").glob("*.log"))
        self.assertEqual(len(logs), 2)
        self.assertTrue(all(p.stat().st_mode & 0o777 == 0o600 for p in logs))
        self.assertEqual(self.state().stat().st_mode & 0o777, 0o700)
        call = json.loads((self.root / "claude.json").read_text())
        self.assertEqual(call["cwd"], str(self.repo))
        self.assertEqual(call["args"][-4:], ["--permission-mode", "dontAsk", "--permission-prompts", "none"])

    def test_requires_runbook_and_checkout_root(self):
        (self.repo / "docs/ops/runbook.md").unlink()
        for result in (self.run_agent(), self.install("--dry-run"), self.run_agent(repo=self.repo / "docs")):
            self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "claude.json").exists())

    def test_permission_bypass_and_raw_arguments_rejected(self):
        for env in ({"OPERATE_APP_PERMISSION_MODE": "bypassPermissions"}, {"OPERATE_APP_CLAUDE_ARGS": "--dangerously-skip-permissions"}):
            self.assertEqual(self.run_agent(**env).returncode, 2)
        self.assertFalse((self.root / "claude.json").exists())

    def test_same_repo_lock_serializes_health_and_daily(self):
        self.assertEqual(self.run_agent().returncode, 0)
        (self.root / "claude.json").unlink()
        with (self.state() / "lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.assertEqual(self.run_agent("daily").returncode, 0)
        self.assertFalse((self.root / "claude.json").exists())
        self.assertIn("daily skipped", (self.state() / "runs/skipped.log").read_text())

    def test_agent_exit_code_and_timeout_preserved(self):
        self.assertEqual(self.run_agent(CLAUDE_EXIT="7").returncode, 7)
        self.assertEqual(self.run_agent(CLAUDE_SLEEP="5", OPERATE_APP_HEALTH_LIMIT="1s").returncode, 124)
        log = "\n".join(p.read_text() for p in (self.state() / "runs").glob("*.log"))
        self.assertIn("exit=7", log)
        self.assertIn("exit=124", log)

    def test_disabling_health_removes_timer_and_has_no_broken_start_hint(self):
        self.assertEqual(self.install().returncode, 0)
        result = self.install("--health", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(list(self.units().glob("*-health.*")))
        self.assertNotIn("start", result.stdout)

    def test_retention_preserves_newest_logs_with_unusual_state_path(self):
        self.env["XDG_STATE_HOME"] = str(self.root / "state with\nnewline")
        self.assertEqual(self.run_agent().returncode, 0)
        state = next((Path(self.env["XDG_STATE_HOME"]) / "operate-app").iterdir())
        runs = state / "runs"
        for i in range(205):
            log = runs / f"old-{i:03}.log"
            log.write_text("old transcript")
            os.utime(log, (i + 1, i + 1))
        (runs / "skipped.log").write_text("skip history")
        self.assertEqual(self.run_agent().returncode, 0)
        self.assertEqual(len(list(runs.glob("*.log"))), 201)
        self.assertFalse((runs / "old-000.log").exists())
        self.assertTrue((runs / "old-204.log").exists())
        self.assertEqual((runs / "skipped.log").read_text(), "skip history")

    def test_failed_disable_does_not_delete_units(self):
        self.assertEqual(self.install().returncode, 0)
        before = {p.name: p.read_bytes() for p in self.units().iterdir()}
        result = self.install("--uninstall", SYSTEMCTL_EXIT="1")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.units().iterdir()})

    def test_uninstall_preserves_transcripts_and_other_repo_units(self):
        other = self.make_repo("two/app")
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(self.install(repo=other).returncode, 0)
        self.assertEqual(self.run_agent().returncode, 0)
        self.assertEqual(self.install("--uninstall").returncode, 0)
        self.assertEqual(len(list(self.units().glob("*.timer"))), 2)
        self.assertTrue(list((self.state() / "runs").glob("*.log")))
        self.assertEqual(self.install("--uninstall").returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
