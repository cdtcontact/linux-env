#!/usr/bin/env python3
"""Check persistent INSERT diagnostics, row changes, and stale ALE jobs."""
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
        # that fresh rows wait, confirmed errors refresh, and old jobs cannot win.
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
                    try:
                        state = json.loads(record.read_text())
                    except FileNotFoundError:
                        # Vim may unlink the previous capture before renaming
                        # the replacement. Retry while that tiny gap is open.
                        continue
                    if state["serial"] > serial:
                        serial = state["serial"]
                        return state
                raise AssertionError("Vim did not capture its diagnostic state")

            def wait_for(predicate, label):
                end = time.monotonic() + 10
                while time.monotonic() < end:
                    # Let delayed diagnostic echo run while Vim is idle. A
                    # tight stream of <Cmd> probes can continually redraw INSERT
                    # or restart cursor timers before the 200 ms echo delay.
                    settle(0.3)
                    state = snapshot()
                    if predicate(state):
                        return state
                raise AssertionError(label + ": " + json.dumps(state))

            def empty(state):
                return not state["loclist"] and not state["signs"]

            def on_row(state, row):
                require(state["mode"].startswith("i") and state["line"] == row,
                        "The edit unexpectedly left INSERT or changed row: " + json.dumps(state))

            def marked(state, row):
                return (any(item["lnum"] == row for item in state["loclist"])
                        and any(sign["lnum"] == row for sign in state["signs"]))

            def error_marked(state, row):
                return (any(item["type"] == "E" and item["lnum"] == row
                            for item in state["loclist"])
                        and any(sign["lnum"] == row for sign in state["signs"]))

            initial = wait_for(lambda s: any("uninitialized" in item["text"]
                                            for item in s["loclist"]), "Initial warning missing")
            require(any(sign["lnum"] == 4 for sign in initial["signs"]),
                    "The compiler warning did not mark printf's use of a")
            # Entering INSERT on an already diagnosed row without changing it
            # must preserve its warning, including the real command-area text.
            keys(b"4G$a")
            untouched = wait_for(lambda s: "uninitialized" in " ".join(s["bottom"]),
                                 "INSERT did not display an existing warning at the cursor")
            on_row(untouched, 4)
            require(untouched["loclist"] == initial["loclist"]
                    and untouched["signs"] == initial["signs"],
                    "Entering INSERT without an edit hid a previously diagnosed row")
            # A change operator deletes text before InsertEnter fires. Keep the
            # confirmed cross-line warning until a real result verifies the fix.
            keys(b"\x1b3Gcc")
            deleted = snapshot()
            on_row(deleted, 3)
            require(marked(deleted, 4), "The cc deletion erased another row's confirmed warning")
            keys(b"int a")
            partial = snapshot()
            on_row(partial, 3)
            require(marked(partial, 4), "An unfinished declaration erased the existing warning")
            keys(b" = 0;")
            fixed = wait_for(lambda s: empty(s) and s["checks"] > initial["checks"]
                             and not s["checking"],
                             "A correct declaration did not clear its cross-line warning in INSERT")
            on_row(fixed, 3)
            require("int a = 0;" in fixed["lines"][2], "The declaration was not repaired")

            keys(b"\x1bOB")  # Actual terminal Down key, without leaving INSERT.
            clean = wait_for(lambda s: empty(s) and not s["checking"],
                             "Moving to the next row restored a corrected warning")
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
            # A manually requested result can arrive while this row is still
            # incomplete. Its error must stay hidden until the cursor leaves.
            keys(b"\x0c")
            active = wait_for(lambda s: s["checks"] > editing["checks"] and not s["checking"],
                              "The active-row checker result did not arrive")
            on_row(active, 4)
            require(empty(active), "A new result displayed errors on the current editing row")
            keys(b"\x1bOB")
            broken = wait_for(lambda s: any(item["type"] == "E" for item in s["loclist"])
                              and not s["checking"], "Leaving the incomplete row did not lint it")
            on_row(broken, 5)
            require(any(item["lnum"] == 4 for item in broken["loclist"]),
                    "The compiler error did not identify the previous row")
            keys(b"\x1bi")
            resumed = snapshot()
            on_row(resumed, 5)
            require(error_marked(resumed, 4),
                    "Re-entering INSERT on another row hid the confirmed error")
            # Spaces and arbitrary code on a different row must not clear the
            # confirmed error. New errors on that unfinished row stay hidden,
            # including when they prevent the compiler from reporting old ones.
            keys(b"\x05 ")
            unrelated_space = snapshot()
            on_row(unrelated_space, 5)
            require(error_marked(unrelated_space, 4),
                    "A space on another row hid the confirmed printf error")
            keys(b"invalid")
            unrelated = wait_for(lambda s: s["checks"] > broken["checks"] and not s["checking"],
                                 "Typing with a confirmed error did not refresh diagnostics")
            on_row(unrelated, 5)
            require(error_marked(unrelated, 4)
                    and not any(item["lnum"] == 5 for item in unrelated["loclist"]),
                    "An unfinished different row hid the old error or showed new errors: "
                    + json.dumps(unrelated))
            keys(b"\x7f" * len("invalid"))
            unrelated_repaired = wait_for(lambda s: s["checks"] > unrelated["checks"]
                                          and not s["checking"],
                                          "Repairing the unrelated row was not checked")
            require(error_marked(unrelated_repaired, 4),
                    "Repairing another row cleared printf's real error")

            # Inserting text before a diagnosed line must move its marker and
            # location-list entry with that line, even before the next result.
            keys(b"\x1b3Go")
            shifted = snapshot()
            on_row(shifted, 4)
            require(error_marked(shifted, 5),
                    "A new line above printf left its diagnostic on the wrong row: "
                    + json.dumps(shifted))
            keys(b"// edit another line")
            shifted = wait_for(lambda s: s["checks"] > unrelated_repaired["checks"]
                               and not s["checking"], "The shifted error was not refreshed")
            require(error_marked(shifted, 5), "Typing on an inserted row hid the shifted error")
            # Returning with only an arrow key is navigation, not a fresh edit.
            # Keep the checked row's signs, location list, and bottom message.
            keys(b"\x1bOB")
            revisited = wait_for(lambda s: "expected" in " ".join(s["bottom"])
                                and ";" in " ".join(s["bottom"]),
                                "Returning in INSERT lost the real compiler error message")
            on_row(revisited, 5)
            require(error_marked(revisited, 5), "Returning to printf hid its confirmed error")

            # A still-incorrect edit keeps the error. Start a slow result, then
            # fix that same row before it finishes: only a current, successful
            # check may clear the old error, without leaving INSERT or the row.
            delay.touch()
            keys(b"\x05 ")
            still_wrong = snapshot()
            on_row(still_wrong, 5)
            require(error_marked(still_wrong, 5),
                    "An incomplete edit on the error row prematurely erased its diagnostic")
            started = wait_for(lambda s: s["checks"] > revisited["checks"] and s["checking"],
                               "The existing error did not trigger a delayed same-row recheck")
            on_row(started, 5)
            require(error_marked(started, 5), "The error disappeared while its recheck was running")
            keys(b";")
            pending_fix = snapshot()
            on_row(pending_fix, 5)
            require(error_marked(pending_fix, 5),
                    "Typing a fix cleared the diagnostic before a compiler verified it")
            repaired = wait_for(lambda s: empty(s) and s["checks"] > started["checks"]
                                and not s["checking"],
                                "A verified fix did not clear the error on the same INSERT row")
            on_row(repaired, 5)
            settle(2.5)
            stale = snapshot()
            on_row(stale, 5)
            require(empty(stale), "A cancelled checker restored stale errors: " + json.dumps(stale))
            delay.unlink()
            keys(b"\x05\r")  # The native paired Enter mapping must also trigger a row check.
            entered = wait_for(lambda s: s["checks"] > repaired["checks"] and not s["checking"],
                               "A real INSERT Enter did not check the corrected buffer")
            on_row(entered, 6)
            require(empty(entered), "A real INSERT Enter restored an obsolete error")
            keys(b"\x1b:qall!\r")
            terminal.finish()
        require(source.read_text() == original, "Background checks rewrote the source on disk")
    print("[diagnostics edit test] Persistent errors, live repairs, row checks, and stale jobs passed",
          flush=True)


if __name__ == "__main__":
    main()
