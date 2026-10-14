#!/usr/bin/env python3
"""Exercise identity setup with a real controlling terminal in a disposable container."""

import errno
import grp
import os
from pathlib import Path
import pty
import pwd
import select
import signal
import subprocess
import sys
import tempfile
import termios
import time


REPO = Path(__file__).resolve().parent.parent
TIMEOUT = 60
NEW_USER = "identitylearner"
# Public test fixtures only: never put a real user's credentials in this file.
PASSWORDS = (b"LinuxEnv-PTY-Test-First-42!", b"LinuxEnv-PTY-Test-Second-57!")
HOST_PROMPT = "请输入主机名".encode()
USER_PROMPT = "请输入开发用户名".encode()
CHANGE_PROMPT = "是否修改密码？[y/N]：".encode()
INSTALL = ["bash", str(REPO / "init_env.sh"), "--skip-packages", "--skip-checks", "--no-change-shell"]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def safe_tail(output):
    for password in PASSWORDS:
        output = output.replace(password, b"<redacted-test-password>")
    return output[-5000:].decode(errors="replace")


def note(message):
    print("[identity test] " + message, flush=True)


def env():
    values = dict(os.environ, LC_ALL="C.UTF-8", TERM="xterm-256color")
    values.pop("SUDO_USER", None)
    return values


def run(*args, check=True):
    result = subprocess.run(args, check=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            stdin=subprocess.DEVNULL, env=env(), timeout=TIMEOUT,
                            start_new_session=True)
    if check:
        require(result.returncode == 0, "Command failed: " + safe_tail(result.stdout))
    return result


class Terminal:
    """pty.fork provides the /dev/tty that passwd and the wizard actually use."""

    def __init__(self, arguments):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvpe(arguments[0], arguments, env())
        os.set_blocking(self.fd, False)
        self.output = bytearray()
        self.cursor = 0
        self.status = None
        self.eof = False
        self.deadline = time.monotonic() + TIMEOUT

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if self.status is None:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(self.pid, 0)
        os.close(self.fd)

    def pump(self):
        require(time.monotonic() < self.deadline,
                "Terminal scenario exceeded 60 seconds: " + safe_tail(bytes(self.output)))
        ready, _, _ = select.select([] if self.eof else [self.fd], [], [], 0.1)
        if ready:
            try:
                chunk = os.read(self.fd, 65536)
                self.output.extend(chunk)
                self.eof = not chunk
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                self.eof = True
        if self.status is None:
            child, status = os.waitpid(self.pid, os.WNOHANG)
            if child:
                self.status = status
        require(len(self.output) < 2_000_000, "Unexpectedly large installer output")
        # No passwords may be present in process arguments, even while passwd runs.
        for entry in Path("/proc").iterdir():
            if entry.name.isdigit():
                try:
                    arguments = (entry / "cmdline").read_bytes()
                except (OSError, ProcessLookupError):
                    continue
                require(not any(secret in arguments for secret in PASSWORDS),
                        "A password appeared in process arguments")

    def expect(self, token):
        while True:
            position = self.output.find(token, self.cursor)
            if position != -1:
                self.cursor = position + len(token)
                return
            require(not (self.eof and self.status is not None),
                    "Terminal ended before expected prompt: " + safe_tail(bytes(self.output)))
            self.pump()

    def send(self, answer):
        os.write(self.fd, answer + b"\n")

    def password(self, password):
        for prompt in (b"New password:", b"Retype new password:"):
            self.expect(prompt)
            # A prompt can be printed just before passwd disables terminal echo.
            # Wait for the actual termios setting before entering sensitive input.
            while termios.tcgetattr(self.fd)[3] & termios.ECHO:
                self.pump()
            self.send(password)

    def finish(self, expected=0):
        while not (self.eof and self.status is not None):
            self.pump()
        code = os.waitstatus_to_exitcode(self.status)
        output = bytes(self.output)
        require(code == expected, "Unexpected terminal exit code: " + safe_tail(output))
        require(not any(secret in output for secret in PASSWORDS),
                "Password input was echoed to the terminal")
        return output


def shadow_hash(username):
    # Read the hash privately; neither hashes nor passwords belong in test output.
    return run("getent", "shadow", username).stdout.split(b":")[1]


def groups(username):
    return run("id", "-G", username).stdout.split()


def system_identity():
    return (Path("/etc/hostname").read_bytes(), Path("/etc/hosts").read_bytes(),
            run("hostname").stdout)


def test_modes():
    note("No terminal and --non-interactive preserve hostname, passwords, and groups")
    before = (system_identity(), shadow_hash("learner"), groups("learner"))
    result = run(*INSTALL, "--user", "learner")
    require(HOST_PROMPT not in result.stdout and USER_PROMPT not in result.stdout,
            "No-terminal invocation unexpectedly prompted")
    with Terminal(INSTALL + ["--user", "learner", "--non-interactive"]) as terminal:
        output = terminal.finish()
        require(HOST_PROMPT not in output and USER_PROMPT not in output,
                "--non-interactive prompted on a terminal")
    require(before == (system_identity(), shadow_hash("learner"), groups("learner")),
            "A noninteractive invocation changed system identity")
    result = run(*INSTALL, "--user", "learner", "--interactive", check=False)
    require(result.returncode != 0 and "交互终端".encode() in result.stdout,
            "--interactive without /dev/tty must fail clearly")
    result = run(*INSTALL, "--non-interactive", "--interactive", check=False)
    require(result.returncode != 0, "Conflicting mode flags must fail")


def test_validation():
    note("Invalid hostnames and new usernames are rejected before accepting defaults")
    before = (system_identity(), shadow_hash("learner"), groups("learner"))
    with Terminal(INSTALL + ["--user", "learner"]) as terminal:
        for invalid in (b"linux123", b"linux-host", b"x" * 64):
            terminal.expect(HOST_PROMPT)
            terminal.send(invalid)
            terminal.expect("主机名只允许".encode())
        terminal.expect(HOST_PROMPT)
        terminal.send(b"")
        terminal.expect(USER_PROMPT)
        terminal.send(b"9invalid")
        terminal.expect("用户名格式不合法".encode())
        terminal.expect(USER_PROMPT)
        terminal.send(b"InvalidNewUser")
        terminal.expect("新用户名需小写字母开头".encode())
        terminal.expect(USER_PROMPT)
        terminal.send(b"")
        terminal.expect(CHANGE_PROMPT)
        terminal.send(b"")
        terminal.finish()
    require(before == (system_identity(), shadow_hash("learner"), groups("learner")),
            "Skipping the identity wizard changed existing account settings")


def test_accounts():
    note("Create a sudo user through native passwd, then preserve or change its password")
    try:
        pwd.getpwnam(NEW_USER)
    except KeyError:
        pass
    else:
        raise AssertionError("Use a fresh container; identity test account already exists")
    hostname_before = system_identity()
    with Terminal(INSTALL) as terminal:
        terminal.expect(HOST_PROMPT)
        terminal.send(b"")
        terminal.expect(USER_PROMPT)
        terminal.send(NEW_USER.encode())
        terminal.password(PASSWORDS[0])
        terminal.finish()
    entry_before = pwd.getpwnam(NEW_USER)
    require(entry_before.pw_uid >= 1000 and entry_before.pw_shell == "/bin/bash",
            "New user must be an ordinary account and respect --no-change-shell")
    require(str(grp.getgrnam("sudo").gr_gid).encode() in groups(NEW_USER),
            "New account is not a member of sudo")
    require((Path(entry_before.pw_dir) / ".config/linux-env/gitconfig").is_file(),
            "New account did not receive the development configuration")
    require(not (Path(entry_before.pw_dir) / ".ssh/authorized_keys").exists(),
            "New account unexpectedly inherited SSH keys")
    initial_hash = shadow_hash(NEW_USER)
    require(initial_hash and not initial_hash.startswith((b"!", b"*")),
            "New account password is still locked")
    marker = Path(entry_before.pw_dir) / "identity-test-personal-file"
    marker.write_text("A personal file must survive identity setup.\n")
    os.chown(marker, entry_before.pw_uid, entry_before.pw_gid)
    account_groups = groups(NEW_USER)
    for change, password in ((False, None), (True, PASSWORDS[1])):
        with Terminal(INSTALL + ["--user", NEW_USER, "--interactive"]) as terminal:
            terminal.expect(HOST_PROMPT)
            terminal.send(b"")
            terminal.expect(USER_PROMPT)
            terminal.send(b"")
            terminal.expect(CHANGE_PROMPT)
            terminal.send(b"y" if change else b"")
            if change:
                terminal.password(password)
            terminal.finish()
        require(pwd.getpwnam(NEW_USER) == entry_before,
                "Reinstall recreated or altered the existing account")
        require(marker.read_text() == "A personal file must survive identity setup.\n",
                "Existing user files were lost")
        require(groups(NEW_USER) == account_groups, "Existing group permissions changed")
        require((shadow_hash(NEW_USER) != initial_hash) == change,
                "Existing account password was not preserved or changed as requested")
    require(system_identity() == hostname_before, "Skipping hostname changed the hostname")


def test_hostname():
    note("Hostname persistence preserves hosts aliases and backs up cloud-init settings")
    # Docker cannot set the kernel hostname without extra capabilities. Exercise
    # the same helper with a temporary filesystem and a narrowly scoped mock.
    with tempfile.TemporaryDirectory(prefix="linux-env-hostname-test-") as directory:
        root = Path(directory)
        (root / "etc/cloud/cloud.cfg.d").mkdir(parents=True)
        (root / "bin").mkdir()
        (root / "etc/hostname").write_text("oldhost\n")
        hosts = b"127.0.0.1 localhost\n127.0.1.1 oldhost oldalias # custom alias\n::1 localhost ip6-localhost\n10.0.0.5 dbserver\n"
        (root / "etc/hosts").write_bytes(hosts)
        (root / "etc/cloud/cloud.cfg").write_text("preserve_hostname: false\n")
        cloud = root / "etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg"
        cloud.write_text("# previous personal cloud setting\n")
        mock = root / "bin/hostname"
        mock.write_text('#!/bin/sh\nprintf "%s\\n" "$1" > "$LINUX_ENV_HOSTNAME_RECORD"\n')
        mock.chmod(0o755)
        script = r'''
set -Eeuo pipefail
log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }
source "$1/scripts/identity.sh"
export PATH="$2/bin:$PATH" LINUX_ENV_HOSTNAME_RECORD="$2/called-hostname"
valid_hostname English
! valid_hostname linux123
! valid_hostname linux-host
! valid_hostname ''
valid_new_username learner_123
! valid_new_username InvalidNewUser
! valid_new_username 9invalid
apply_hostname StudyHost "$2"
'''
        run("bash", "-c", script, "bash", str(REPO), directory)
        require((root / "called-hostname").read_text() == "studyhost\n",
                "Kernel hostname helper received the wrong hostname")
        require((root / "etc/hostname").read_text() == "studyhost\n",
                "Persistent hostname was not written")
        updated_hosts = (root / "etc/hosts").read_bytes()
        require(b"127.0.1.1\tstudyhost oldhost oldalias # custom alias" in updated_hosts,
                "Existing hosts aliases or comments were lost")
        require(b"10.0.0.5 dbserver\n" in updated_hosts and b"::1 localhost ip6-localhost\n" in updated_hosts,
                "Unrelated hosts entries were lost")
        require(cloud.read_text() == "preserve_hostname: true\nmanage_etc_hosts: false\n",
                "cloud-init may overwrite the new hostname")
        backups = list((root / "var/backups/linux-env").glob("hostname-*"))
        require(len(backups) == 1 and (backups[0] / "hosts").read_bytes() == hosts,
                "Original hosts file was not backed up")
        require((backups[0] / "hostname").read_text() == "oldhost\n"
                and (backups[0] / "cloud-hostname.cfg").read_text() == "# previous personal cloud setting\n",
                "Original hostname or cloud-init setting was not backed up")
        # A failing kernel operation must leave all persistent files untouched.
        before = ((root / "etc/hostname").read_bytes(), updated_hosts, cloud.read_bytes())
        mock.write_text("#!/bin/sh\nexit 1\n")
        result = run("bash", "-c", script, "bash", str(REPO), directory, check=False)
        require(result.returncode != 0, "Kernel hostname failure did not stop installation")
        require(before == ((root / "etc/hostname").read_bytes(), (root / "etc/hosts").read_bytes(), cloud.read_bytes()),
                "Kernel hostname failure changed persistent files")


def main():
    require(os.geteuid() == 0, "Run the identity tests as root in the integration container")
    require(Path("/.dockerenv").is_file() or os.environ.get("LINUX_ENV_TEST_ALLOW_HOST") == "1",
            "Refusing account changes outside a disposable container")
    test_modes()
    test_validation()
    test_accounts()
    test_hostname()
    for log in Path("/var/log/linux-env").glob("*.log"):
        require(not any(secret in log.read_bytes() for secret in PASSWORDS),
                "A password appeared in an installer log")
    note("All real-terminal and hostname checks passed; passwords stayed out of logs and argv")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, subprocess.SubprocessError) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
