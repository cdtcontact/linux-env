#!/usr/bin/env python3
"""Test new buffers and actual Tab/Enter keys without opening a user's projects."""
import os
from pathlib import Path
import tempfile
import time

from identity import REPO, Terminal, require, run


def test_vim(root):
    for extension, expected in (("c", "#include <stdio.h>"),
                                ("cpp", "#include <iostream>"),
                                ("py", "import sys")):
        path = root / ("new." + extension)
        run("vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n", "-es",
            "-c", "edit " + str(path), "-c", "write", "-c", "qa!")
        text = path.read_text()
        for value in (path.name, "chendatao", "peacecdt@gmail.com", "Created Time:", expected):
            require(value in text, "New file header is incomplete: " + extension)
        run("vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n", "-es",
            "-c", "edit " + str(path), "-c", "write", "-c", "qa!")
        require(path.read_text() == text, "Existing file was rewritten")
        if extension == "py":
            run("python3", "-m", "py_compile", str(path))
        else:
            run("gcc" if extension == "c" else "g++", "-fsyntax-only", str(path))
    empty = root / "existing.c"
    empty.touch()
    run("vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n", "-es",
        "-c", "edit " + str(empty), "-c", "write", "-c", "qa!")
    require(empty.read_bytes() == b"", "Existing empty file received an unwanted header")
    unsaved = root / "unsaved.py"
    run("vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n", "-es",
        "-c", "edit " + str(unsaved), "-c", "qa!")
    require(not unsaved.exists(), "Opening an unsaved buffer created a file")


def test_shell(root, keys, expected, files, history=""):
    case = root / ("shell-" + str(len(list(root.iterdir()))))
    case.mkdir()
    for name in files:
        (case / name).touch()
    record = case / "opened.txt"
    (case / "history").write_text(history)
    # Source the real plugins and ZLE config, but record vim's argument instead
    # of launching a full-screen editor. Use a stable prompt for synchronization.
    rc = ('source ' + str(REPO / 'config/zshrc') + '\n'
          'HISTFILE=' + str(case / 'history') + '\n'
          'fc -R "$HISTFILE"\n'
          'vim() { print -r -- "$*" > ' + str(record) + '; print -r -- OPENED; }\n'
          'cd ' + str(case) + '\n'
          "PROMPT='READY> '; RPROMPT=''\n")
    script = case / "start.zsh"
    script.write_text(rc)
    with Terminal(["zsh", "-dfi"]) as terminal:
        terminal.send(("source " + str(script)).encode())
        terminal.expect(b"READY>")
        terminal.send(b"bindkey '^M'")
        terminal.expect(b"_linux_env_accept_line")
        terminal.expect(b"READY>")
        os.write(terminal.fd, keys)
        if not keys.endswith(b"\r"):
            until = time.monotonic() + 0.5
            while time.monotonic() < until:
                terminal.pump()
            os.write(terminal.fd, b"\r")
        terminal.expect(b"OPENED")
        terminal.expect(b"READY>")
        terminal.send(b"exit")
        terminal.finish()
    require(record.read_text().strip() == expected,
            "Tab/Enter selected the wrong filename: " + record.read_text())


def main():
    with tempfile.TemporaryDirectory(prefix="linux-env-editor-") as directory:
        root = Path(directory)
        test_vim(root)
        test_shell(root, b"vim uni\r", "unique.c", ["unique.c"])
        test_shell(root, b"vim uni\t\r", "unique.cpp", ["unique.cpp"])
        test_shell(root, b"vim exact.c\r", "exact.c", ["exact.c", "exact.cpp"])
        test_shell(root, b"vim new.c\r", "new.c", [])
        # Enter accepts the displayed filename from history even when the local
        # prefix alone is ambiguous. It must not create a truncated filename.
        test_shell(root, b"vim bet", "beta.cpp", ["beta.c", "beta.cpp"], "vim beta.cpp\n")
        test_shell(root, b"vim other.py\r", "other.py", ["other.py"])
    print("Vim new-file headers and real Zsh Tab/Enter checks passed.")


if __name__ == "__main__":
    main()
