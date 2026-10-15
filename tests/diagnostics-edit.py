#!/usr/bin/env python3
"""Check real insert-mode edits, row changes, and cancellation of old ALE jobs."""
import json
import os
from pathlib import Path
import shlex
import tempfile
import time

from identity import REPO, Terminal, require


def main():
    with tempfile.TemporaryDirectory(prefix="linux-env-diagnostic-edit-") as temporary:
        root = Path(temporary)
        source = root / "example.c"
        original = ('#include <stdio.h>\nint main(void) {\n    int a;\n'
                    '    printf("%d\\n", a);\n    return 0;\n}\n')
        source.write_text(original)
        calls, delay = root / "checks", root / "delay"
        compiler = root / "clang"
        # A real compiler behind a tiny delay/count wrapper lets the test prove
        # that typing does not start jobs and a superseded result cannot return.
        compiler.write_text('#!/bin/sh\nprintf "check\\n" >> ' + shlex.quote(str(calls))
                            + '\nif [ -f ' + shlex.quote(str(delay)) + ' ]; then sleep 2; fi\n'
                            + 'exec /usr/bin/clang "$@"\n')
        compiler.chmod(0o755)
        record = root / "state.json"
        descriptor = root / "case.json"
        descriptor.write_text(json.dumps({"source": str(source), "compiler": str(compiler),
                                          "output": str(record), "calls": str(calls)}))
        with Terminal(["vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n",
                       "-c", "let g:diagnostic_edit_case = '" + str(descriptor) + "'",
                       "-S", str(REPO / "tests/vim-diagnostics-edit.vim")]) as terminal:
            serial = 0

            def settle(seconds=0.5):
                end = time.monotonic() + seconds
                while time.monotonic() < end:
                    terminal.pump()

            def keys(value):
                os.write(terminal.fd, value)
                settle(0.2)

            def snapshot():
                nonlocal serial
                os.write(terminal.fd, b"\x07")
                end = time.monotonic() + 5
                while time.monotonic() < end:
                    terminal.pump()
                    if record.exists():
                        state = json.loads(record.read_text())
                        if state["serial"] > serial:
                            serial = state["serial"]
                            return state
                raise AssertionError("Vim did not capture its diagnostic state")

            def wait_for(predicate, label):
                end = time.monotonic() + 10
                while time.monotonic() < end:
                    state = snapshot()
                    if predicate(state):
                        return state
                raise AssertionError(label + ": " + json.dumps(state))

            def empty(state):
                return not state["loclist"] and not state["signs"]

            def on_row(state, row):
                require(state["mode"].startswith("i") and state["line"] == row,
                        "The edit unexpectedly left INSERT or changed row: " + json.dumps(state))

            initial = wait_for(lambda s: any("uninitialized" in item["text"]
                                            for item in s["loclist"]), "Initial warning missing")
            require(any(sign["lnum"] == 4 for sign in initial["signs"]),
                    "The compiler warning did not mark printf's use of a")
            # A change operator deletes text before InsertEnter fires. Even
            # before typing the replacement, its old cross-line warning is stale.
            keys(b"3Gcc")
            deleted = snapshot()
            on_row(deleted, 3)
            require(empty(deleted), "The cc deletion kept stale cross-line diagnostics")
            keys(b"int a = 0;")
            fixed = snapshot()
            on_row(fixed, 3)
            require("int a = 0;" in fixed["lines"][2] and empty(fixed),
                    "A real INSERT edit kept stale cross-line diagnostics: " + json.dumps(fixed))

            keys(b"\x1bOB")  # Actual terminal Down key, without leaving INSERT.
            clean = wait_for(lambda s: s["checks"] > initial["checks"] and not s["checking"],
                             "Moving to the next row did not check the corrected buffer")
            on_row(clean, 4)
            require(empty(clean), "The corrected buffer still reported a compiler warning")
            # Remove printf's semicolon, then pause on that same editing row.
            keys(b"\x05\x7f")
            settle()
            editing = snapshot()
            on_row(editing, 4)
            require(editing["lines"][3].endswith(")") and empty(editing)
                    and editing["checks"] == clean["checks"],
                    "Typing on one row caused premature checks: " + json.dumps(editing))
            keys(b"\x1bOB")
            broken = wait_for(lambda s: any(item["type"] == "E" for item in s["loclist"])
                              and not s["checking"], "Leaving the incomplete row did not lint it")
            on_row(broken, 5)
            require(any(item["lnum"] == 4 for item in broken["loclist"]),
                    "The compiler error did not identify the previous row")
            keys(b"\x1bOA\x05;")
            repaired = snapshot()
            on_row(repaired, 4)
            require(empty(repaired), "Correcting printf kept its old error while in INSERT")
            keys(b"\x1bOB")
            refreshed = wait_for(lambda s: s["checks"] > broken["checks"] and not s["checking"],
                                 "Corrected code was not rechecked on a row change")
            require(empty(refreshed), "Corrected printf did not clear diagnostics")

            delay.touch()
            keys(b"\x1bOA")
            keys(b"\x05\x7f")
            keys(b"\x1bOB")
            started = wait_for(lambda s: s["checks"] > refreshed["checks"] and s["checking"],
                               "Delayed compiler job did not start")
            on_row(started, 5)
            keys(b" ")  # Invalidate that job from a different row while it is running.
            settle(2.5)
            stale = snapshot()
            on_row(stale, 5)
            require(empty(stale), "A cancelled checker restored stale errors: " + json.dumps(stale))
            delay.unlink()
            keys(b"\x1bOA")
            keys(b"\x1bOB")
            final = wait_for(lambda s: any(item["type"] == "E" for item in s["loclist"])
                            and not s["checking"], "A fresh row change did not restore checking")
            on_row(final, 5)
            keys(b"\x1bOA\x05;")
            require(empty(snapshot()), "Final INSERT correction did not clear the error")
            keys(b"\x1b:qall!\r")
            terminal.finish()
        require(source.read_text() == original, "Background checks rewrote the source on disk")
    print("[diagnostics edit test] Real INSERT edits, row checks, and stale-job cancellation passed",
          flush=True)


if __name__ == "__main__":
    main()
