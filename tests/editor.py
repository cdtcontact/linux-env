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


def test_live_suggestions(root):
    case = root / "suggestions"
    case.mkdir()
    (case / "elsewhere").mkdir()
    deleted = case / "12.c"
    deleted.touch()
    (case / "keep.c").touch()
    (case / "my source.c").touch()
    history = case / "history"
    # These lines must remain searchable, but never supply stale gray filenames.
    history.write_text("rm 12.c\ngcc 12.c\ngcc -Wall 12.c\nvim 12.c\ncat 12.c\n"
                       "cp 12.c missing.c\nrm absent.c\ngcc -o absent 12.c\n")
    record = case / "suggestion.txt"
    script = case / "start.zsh"
    script.write_text(
        'source ' + str(REPO / 'config/zshrc') + '\n'
        'HISTFILE=' + str(history) + '\n'
        'fc -R "$HISTFILE"\n'
        # Synchronous fetching makes the snapshot deterministic while using the
        # real completion engine and plugin widgets inside a controlling PTY.
        'unset ZSH_AUTOSUGGEST_USE_ASYNC\n'
        'ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(linux-env-test-capture)\n'
        'linux-env-test-capture() {\n'
        '  print -r -- "${BUFFER}${POSTDISPLAY}" > ' + str(record) + '\n'
        '  zle .send-break\n'
        '}\n'
        'zle -N linux-env-test-capture\n'
        "bindkey '^G' linux-env-test-capture\n"
        'cd ' + str(case) + '\n'
        "PROMPT='READY> '; RPROMPT=''\n")
    with Terminal(["zsh", "-dfi"]) as terminal:
        terminal.send(("source " + str(script)).encode())
        terminal.expect(b"READY>")

        def snapshot(typed):
            os.write(terminal.fd, typed.encode())
            until = time.monotonic() + 0.5
            while time.monotonic() < until:
                terminal.pump()
            os.write(terminal.fd, b"\x07")
            terminal.expect(b"READY>")
            return record.read_text().strip()

        require(snapshot("rm 12") == "rm 12.c", "Existing rm filename was not suggested")
        require(snapshot("gcc 12") == "gcc 12.c", "Existing gcc input was not suggested")
        deleted.unlink()
        for prefix in ("rm 12", "gcc 12", "gcc -Wall 12", "vim 12", "cat 12", "cp 12",
                       "rm abs", "gcc -o abs"):
            visible = snapshot(prefix)
            require(visible == prefix, "Deleted/missing file reappeared: " + visible)
        require(snapshot("rm keep") == "rm keep.c", "Other live files stopped completing")
        require(snapshot('rm "my ') == 'rm "my source.c"', "Quoted filename completion failed")
        (case / "13.c").touch()
        require(snapshot("gcc 13") == "gcc 13.c", "Newly created file was not suggested")
        terminal.send(b"cd elsewhere")
        terminal.expect(b"READY>")
        require(snapshot("rm keep") == "rm keep", "Filename leaked from the previous directory")
        # The capture widget cancels the input line, leaving a nonzero status.
        terminal.send(b"exit 0")
        terminal.finish()
    require("rm 12.c" in history.read_text(), "Suggestion filtering erased command history")


def main():
    with tempfile.TemporaryDirectory(prefix="linux-env-editor-") as directory:
        root = Path(directory)
        test_vim(root)
        test_shell(root, b"vim uni\r", "unique.c", ["unique.c"])
        test_shell(root, b"vim uni\t\r", "unique.cpp", ["unique.cpp"])
        test_shell(root, b"vim exact.c\r", "exact.c", ["exact.c", "exact.cpp"])
        test_shell(root, b"vim new.c\r", "new.c", [])
        # Enter accepts the displayed live completion even with an ambiguous
        # prefix and stale history. It must not create a truncated filename.
        test_shell(root, b"vim bet", "beta.c", ["beta.c", "beta.cpp"], "vim beta-old.cpp\n")
        test_shell(root, b"vim other.py\r", "other.py", ["other.py"])
        test_live_suggestions(root)
    print("Vim headers, real Zsh Tab/Enter, and live filename suggestion checks passed.")


if __name__ == "__main__":
    main()
