#!/usr/bin/env python3
"""Check sudo arguments and the rendered command left behind by real ZLE."""

import fcntl
import os
from pathlib import Path
import re
import shlex
import struct
import tempfile
import termios
import time

from identity import REPO, Terminal, require


class Screen:
    """Small VT row renderer: keep erasure/redraw effects, discard styling."""

    def __init__(self):
        self.rows = [[" "] * 120 for _ in range(40)]
        self.row = self.column = 0
        self.saved = (0, 0)
        self.history = []

    def down(self):
        self.row += 1
        if self.row == len(self.rows):
            self.history.append("".join(self.rows.pop(0)).rstrip())
            self.rows.append([" "] * 120)
            self.row -= 1

    def feed(self, output):
        text = output.decode(errors="replace")
        index = 0
        while index < len(text):
            char = text[index]
            if char == "\x1b":
                csi = re.match(r"\x1b\[([0-?]*)([ -/]*)([@-~])", text[index:])
                if csi:
                    parameters, _, operation = csi.groups()
                    values = [int(value or "0") for value in parameters.split(";")
                              if value.isdigit() or not value]
                    value = values[0] if values else 0
                    count = value or 1
                    if operation in ("H", "f"):
                        self.row = min(39, count - 1)
                        self.column = min(119, (values[1] or 1) - 1 if len(values) > 1 else 0)
                    elif operation in ("G", "`"):
                        self.column = min(119, count - 1)
                    elif operation == "A":
                        self.row = max(0, self.row - count)
                    elif operation == "B":
                        self.row = min(39, self.row + count)
                    elif operation == "C":
                        self.column = min(119, self.column + count)
                    elif operation == "D":
                        self.column = max(0, self.column - count)
                    elif operation == "K":
                        start, end = ((0, self.column + 1) if value == 1 else
                                      (0, 120) if value == 2 else (self.column, 120))
                        self.rows[self.row][start:end] = [" "] * (end - start)
                    elif operation == "J":
                        if value == 2:
                            self.rows = [[" "] * 120 for _ in range(40)]
                        elif value == 0:
                            self.rows[self.row][self.column:] = [" "] * (120 - self.column)
                            for row in range(self.row + 1, 40):
                                self.rows[row] = [" "] * 120
                    elif operation == "X":
                        end = min(120, self.column + count)
                        self.rows[self.row][self.column:end] = [" "] * (end - self.column)
                    elif operation == "P":
                        row = self.rows[self.row]
                        self.rows[self.row] = (row[:self.column] + row[self.column + count:] +
                                               [" "] * count)[:120]
                    elif operation == "@":
                        row = self.rows[self.row]
                        self.rows[self.row] = (row[:self.column] + [" "] * count +
                                               row[self.column:])[:120]
                    # SGR and private terminal mode switches do not alter text.
                    index += len(csi.group())
                    continue
                osc = re.match(r"\x1b\].*?(?:\x07|\x1b\\)", text[index:], re.DOTALL)
                if osc:
                    index += len(osc.group())
                    continue
                if text[index:index + 3] in ("\x1b(B", "\x1b)B"):
                    index += 3
                    continue
                if text[index:index + 2] == "\x1b7":
                    self.saved = (self.row, self.column)
                elif text[index:index + 2] == "\x1b8":
                    self.row, self.column = self.saved
                index += 2
                continue
            if char == "\r":
                self.column = 0
            elif char == "\n":
                self.down()
            elif char == "\b":
                self.column = max(0, self.column - 1)
            elif char == "\t":
                self.column = min(119, (self.column // 8 + 1) * 8)
            elif char >= " ":
                if self.column == 120:
                    self.column = 0
                    self.down()
                self.rows[self.row][self.column] = char
                self.column += 1
            index += 1

    def lines(self):
        return self.history + ["".join(row).rstrip() for row in self.rows]


def settle(terminal, seconds=0.5):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        terminal.pump()


def rendered(output):
    screen = Screen()
    screen.feed(b"READY> " + output)
    return screen.lines()


def test_sudo(root, asynchronous):
    case = root / ("async" if asynchronous else "sync")
    case.mkdir()
    arguments = case / "arguments.txt"
    snapshot_file = case / "snapshot.txt"
    script = case / "start.zsh"
    script.write_text(
        "source " + shlex.quote(str(REPO / "config/zshrc")) + "\n"
        "HISTFILE=" + shlex.quote(str(case / "history")) + "\n"
        + ("" if asynchronous else "unset ZSH_AUTOSUGGEST_USE_ASYNC\n") +
        "sudo() { print -rl -- \"$@\" > " + shlex.quote(str(arguments)) +
        "; print -r -- SUDO-DONE; }\n"
        "say() { print -rl -- \"$@\" > " + shlex.quote(str(arguments)) +
        "; print -r -- SAY-DONE; }\n"
        "ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(linux-env-test-inject linux-env-test-snapshot)\n"
        "linux-env-test-inject() {\n"
        "  case \"$BUFFER\" in\n"
        "    'sudo -i') POSTDISPLAY='A' ;;\n"
        "    'say te') POSTDISPLAY='st' ;;\n"
        "  esac\n"
        "  zle -R\n"
        "}\n"
        "zle -N linux-env-test-inject\n"
        "bindkey '^X' linux-env-test-inject\n"
        "linux-env-test-snapshot() {\n"
        "  print -r -- \"$BUFFER\" \"$POSTDISPLAY\" > " + shlex.quote(str(snapshot_file)) + "\n"
        "  zle -I\n"
        "  print -r -- SNAPSHOT-DONE\n"
        "  zle .send-break\n"
        "}\n"
        "zle -N linux-env-test-snapshot\n"
        "bindkey '^G' linux-env-test-snapshot\n"
        "cd " + shlex.quote(str(case)) + "\n"
        "PROMPT='READY> '; RPROMPT=''\n")
    with Terminal(["zsh", "-dfi"]) as terminal:
        fcntl.ioctl(terminal.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        terminal.send(("source " + shlex.quote(str(script))).encode())
        terminal.expect(b"READY>")
        settle(terminal, 0.2)

        def snapshot(inject):
            os.write(terminal.fd, b"sudo -i")
            settle(terminal)
            if inject:
                os.write(terminal.fd, b"\x18")
                settle(terminal, 0.2)
            os.write(terminal.fd, b"\x07")
            terminal.expect(b"SNAPSHOT-DONE")
            terminal.expect(b"READY>")
            settle(terminal, 0.2)
            require(snapshot_file.read_text().rstrip("\n") == "sudo -i ",
                    "sudo -i acquired a gray option suffix: " + repr(snapshot_file.read_text()))

        snapshot(False)
        snapshot(True)

        def execute(keys, expected, command, sentinel, inject=False):
            start = len(terminal.output)
            os.write(terminal.fd, keys)
            settle(terminal)
            if inject:
                os.write(terminal.fd, b"\x18")
                settle(terminal, 0.2)
                before_enter = bytes(terminal.output[start:])
                before_lines = rendered(before_enter)
                require("READY> say test" in before_lines,
                        "Ordinary command did not display the injected, unaccepted gray suffix: " +
                        repr(before_lines) + "; terminal bytes=" + repr(before_enter))
            os.write(terminal.fd, b"\r")
            terminal.expect(sentinel)
            terminal.expect(b"READY>")
            settle(terminal, 0.2)
            require(arguments.read_text().splitlines() == expected,
                    "Enter changed the requested arguments: " + repr(arguments.read_text()))
            lines = rendered(bytes(terminal.output[start:]))
            require("READY> " + command in lines,
                    "Accepted command did not repaint before execution: " + repr(lines))
            require(not any(line.startswith("READY> " + command) and
                            line != "READY> " + command for line in lines),
                    "Unaccepted gray text remained on the submitted command: " + repr(lines))

        execute(b"sudo -i", ["-i"], "sudo -i", b"SUDO-DONE")
        # Explicit Tab still invokes sudo's option completer, even though gray
        # option suggestions are disabled. --login is supported by every image.
        execute(b"sudo --logi\t", ["--login"], "sudo --login", b"SUDO-DONE")
        execute(b"say te", ["te"], "say te", b"SAY-DONE", inject=True)
        terminal.send(b"exit 0")
        terminal.finish()


def main():
    # The renderer must distinguish a stale display from a correctly erased one.
    require("READY> sudo -iA" in rendered(b"sudo -iA\r\n"), "Renderer missed a ghost suffix")
    require("READY> sudo -i" in rendered(b"sudo -iA\b\x1b[K\r\n"),
            "Renderer ignored erase-to-end-of-line")
    with tempfile.TemporaryDirectory(prefix="linux-env-sudo-suggestions-") as directory:
        root = Path(directory)
        test_sudo(root, asynchronous=True)
        test_sudo(root, asynchronous=False)
    print("Real Zsh sudo/Tab arguments and submitted command display checks passed.")


if __name__ == "__main__":
    main()
