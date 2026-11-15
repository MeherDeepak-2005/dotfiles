import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def find_bash():
    if os.name == "nt":
        # Windows' System32/bash.exe is a WSL launcher, not Git Bash.
        git = shutil.which("git")
        if git:
            for parent in Path(git).resolve().parents:
                candidate = parent / "bin/bash.exe"
                if candidate.is_file():
                    return str(candidate)
        raise RuntimeError("Git Bash is required for Windows installer tests")
    return shutil.which("bash")


BASH = find_bash()


def bash_path(path):
    if os.name == "nt":
        cygpath = Path(BASH).parent.parent / "usr/bin/cygpath.exe"
        return subprocess.check_output([str(cygpath), "-u", str(path)], text=True).strip()
    return str(path)


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-tests-")
        self.base = Path(self.temp.name)
        self.source = self.base / "source config"
        self.source.mkdir()
        (self.source / "new.conf").write_text("new\n")
        self.dest = self.base / "existing config"

    def tearDown(self):
        self.temp.cleanup()

    def bash(self, body, policy="backup", success=True):
        env = os.environ.copy()
        env.update(TEST_ROOT=bash_path(self.base), TEST_SOURCE=bash_path(self.source), TEST_DEST=bash_path(self.dest),
                   TEST_REPO=bash_path(ROOT), TEST_POLICY=policy)
        prelude = '''set -euo pipefail
log() { printf '%s\\n' "$*"; }
die() { printf '%s\\n' "$*" >&2; exit 1; }
CONFIG_HOME="$TEST_ROOT/config"
DATA_HOME="$TEST_ROOT/data"
BACKUP_ROOT="$TEST_ROOT/backups"
EXISTING=$TEST_POLICY
source "$TEST_REPO/lib/deploy.sh"
'''
        if os.name == "nt":
            env["PATH"] = str(Path(BASH).parent.parent / "usr/bin") + os.pathsep + env["PATH"]
        result = subprocess.run([BASH, "-c", prelude + body], env=env, text=True,
                                capture_output=True, start_new_session=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_new_deployment_and_repeat_noop(self):
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"; test "$DEPLOYED" -eq 1')
        inode = (self.dest / "new.conf").stat().st_ino
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"; test "$DEPLOYED" -eq 1')
        self.assertEqual(inode, (self.dest / "new.conf").stat().st_ino)
        self.assertFalse((self.base / "backups").exists())

    def test_backup_replaces_whole_directory_and_preserves_old_files(self):
        self.dest.mkdir()
        (self.dest / "old.conf").write_text("keep this in backup\n")
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"')
        backups = list((self.base / "backups").rglob("old.conf"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "keep this in backup\n")
        self.assertEqual(list(p.name for p in self.dest.iterdir()), ["new.conf"])

    def test_keep_does_not_merge_or_run_new_config(self):
        self.dest.mkdir()
        (self.dest / "old.conf").write_text("original")
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"; test "$DEPLOYED" -eq 0', policy="keep")
        self.assertFalse((self.dest / "new.conf").exists())
        self.assertEqual((self.dest / "old.conf").read_text(), "original")

    def test_unchanged_config_counts_as_deployed_even_with_keep_policy(self):
        shutil.copytree(self.source, self.dest)
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"; test "$DEPLOYED" -eq 1', policy="keep")

    def test_delete_requires_exact_destination_confirmation(self):
        self.dest.mkdir()
        (self.dest / "old.conf").write_text("old")
        self.bash('''ask() {
  if [ -z "${ASKED:-}" ]; then ANSWER=d; ASKED=1; else ANSWER="DELETE $TEST_DEST"; fi
}
deploy "$TEST_SOURCE" "$TEST_DEST"
''', policy="prompt")
        self.assertFalse((self.dest / "old.conf").exists())
        self.assertTrue((self.dest / "new.conf").exists())

    def test_incorrect_delete_confirmation_keeps_original(self):
        self.dest.mkdir()
        (self.dest / "old.conf").write_text("old")
        self.bash('''ask() {
  if [ -z "${ASKED:-}" ]; then ANSWER=d; ASKED=1; else ANSWER=DELETE; fi
}
deploy "$TEST_SOURCE" "$TEST_DEST"
''', policy="prompt")
        self.assertTrue((self.dest / "old.conf").exists())
        self.assertFalse((self.dest / "new.conf").exists())

    def test_noninteractive_conflict_fails_without_touching_original(self):
        self.dest.mkdir()
        (self.dest / "old.conf").write_text("original")
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"', policy="prompt", success=False)
        self.assertEqual((self.dest / "old.conf").read_text(), "original")

    def test_symlink_replacement_does_not_delete_its_target(self):
        outside = self.base / "outside"
        outside.mkdir()
        (outside / "valuable").write_text("untouched")
        try:
            self.dest.symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest("Creating symlinks requires developer mode on this Windows runner")
        self.bash('deploy "$TEST_SOURCE" "$TEST_DEST"')
        self.assertEqual((outside / "valuable").read_text(), "untouched")
        self.assertFalse(self.dest.is_symlink())

    def test_rejects_config_root_equal_to_home(self):
        self.bash('CONFIG_HOME=$HOME; validate_roots', success=False)

    def test_rejects_relative_roots(self):
        self.bash('CONFIG_HOME=relative; validate_roots', success=False)


class RenderingTests(unittest.TestCase):
    def test_both_platforms_preserve_the_same_movement_and_split_bindings(self):
        with tempfile.TemporaryDirectory() as temp:
            for platform, shell in [("macos", "/opt/homebrew/bin/zsh"),
                                    ("linux", "/home/linuxbrew/.linuxbrew/bin/zsh"),
                                    ("windows", "C:/Program Files/Git/bin/bash.exe")]:
                output = Path(temp) / (platform + ".conf")
                subprocess.run(["python3", str(ROOT / "scripts/render-config.py"),
                                "--platform", platform, "--shell", shell,
                                "--entry", "C:/Users/Ann Lee/.psmux.conf" if platform == "windows" else "/home/Ann Lee/.tmux.conf",
                                "--output", str(output)], check=True)
                text = output.read_text()
                self.assertNotIn("@SHELL@", text)
                self.assertNotIn("@ENTRY@", text)
                self.assertIn('set -g default-shell "' + shell + '"', text)
                for key, direction in [("h", "L"), ("j", "D"), ("k", "U"), ("l", "R")]:
                    self.assertEqual(text.count("bind -n M-" + key + " select-pane -" + direction), 1)
                self.assertIn('bind -n M-v split-window -h -c "#{pane_current_path}"', text)
                self.assertNotIn("bind -n M-y", text)
                self.assertIn("bind y split-window -v", text)
                self.assertIn("prediction-dimming", text) if platform == "windows" else None
                if platform == "windows":
                    self.assertNotIn("terminal-features", text)
                    self.assertNotIn("/bin/zsh", text)

    def test_cli_dry_run_and_invalid_options(self):
        result = subprocess.run([BASH, bash_path(ROOT / "startup.sh"), "--dry-run"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("DRY RUN", result.stdout)
        self.assertNotEqual(subprocess.run([BASH, bash_path(ROOT / "startup.sh"), "--unknown"], capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
