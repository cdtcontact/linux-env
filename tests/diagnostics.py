#!/usr/bin/env python3
"""Exercise real compiler/Flake8 diagnostics in Vim without running the program."""
import json
from pathlib import Path
import shlex
import tempfile

from identity import REPO, Terminal, require, run


def test_plugin_startup(root):
    record = root / "startup.txt"
    # A normal terminal launch must load ALE without the explicit runtime call
    # needed by the Ex-mode checker fixture below.
    with Terminal(["vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n",
                   "-c", "call writefile([string(exists(':ALELint'))], '" + str(record) + "')",
                   "-c", "qall!"]) as terminal:
        terminal.finish()
    require(record.read_text().strip() == "2", "Normal Vim startup did not load ALE")
    print("[diagnostics test] Normal terminal Vim startup loaded ALE", flush=True)


def test_diagnostics(root, extension, syntax_error=False):
    case = root / (extension + "-syntax" if syntax_error else extension)
    case.mkdir()
    source = case / ("example." + extension)
    marker = case / "PROGRAM_WAS_EXECUTED"
    if extension == "py":
        broken = ["from pathlib import Path", f'Path("{marker}").touch()',
                  "if True print(0)" if syntax_error else "print(missing_symbol)"]
        fixed = broken[:-1] + ["print(0)"]
        error_line = 3
    else:
        include = case / "private-include"
        include.mkdir()
        (include / "diagnostic_value.h").write_text("#define DIAGNOSTIC_TEST_VALUE 0\n")
        # This header is deliberately outside the source directory. ALE must
        # honor the project's compile database, as with a CMake project.
        command = ["clang++" if extension == "cpp" else "clang",
                   "-I", str(include), "-c", str(source)]
        (case / "compile_commands.json").write_text(json.dumps([{
            "directory": str(case), "file": str(source),
            "command": " ".join(map(shlex.quote, command)),
        }]))
        broken = ['#include <stdio.h>', '#include "diagnostic_value.h"',
                  "int main(void) {", "    int unused = 0;",
                  f'    FILE *marker = fopen("{marker}", "w");',
                  "    if (marker != NULL) fclose(marker);",
                  "    return missing_symbol;", "}"]
        fixed = list(broken)
        fixed[3] = "    int result = DIAGNOSTIC_TEST_VALUE;"
        fixed[6] = "    return result;"
        warning = list(fixed)
        warning[3] = "    int unused = 0;"
        warning[6] = "    return DIAGNOSTIC_TEST_VALUE;"
        error_line = 7

    original = "\n".join(broken) + "\n"
    source.write_text(original)
    output = case / "result.json"
    descriptor = case / "case.json"
    case_data = {"path": str(source), "output": str(output),
                 "broken": broken, "fixed": fixed}
    if extension != "py":
        case_data["warning"] = warning
    descriptor.write_text(json.dumps(case_data))
    result = run("vim", "-Nu", str(REPO / "config/vimrc"), "-i", "NONE", "-n", "-es",
                 "-c", "let g:diagnostic_case_path = '" + str(descriptor) + "'",
                 "-S", str(REPO / "tests/vim-diagnostics.vim"), check=False)
    require(output.exists(), "Vim diagnostic fixture failed: " + result.stdout.decode(errors="replace"))
    state = json.loads(output.read_text())
    require(result.returncode == 0 and not state.get("failure"),
            extension + " diagnostic fixture failed: " + json.dumps(state))
    for phase in ("initial", "saved"):
        diagnostics = state[phase]["loclist"]
        error_text = "invalid syntax" if syntax_error else "missing_symbol"
        require(any(item["lnum"] == error_line and error_text in item["text"]
                    and item["type"] == "E" for item in diagnostics),
                case.name + " " + phase + " did not show the real checker error: "
                + json.dumps(state[phase]))
        require(any(sign["name"] == "ALEErrorSign" and sign["lnum"] == error_line
                    for sign in state[phase]["signs"]),
                extension + " did not place an error marker")
    if extension != "py":
        warnings = state["warning"]["loclist"]
        require(any(item["lnum"] == 4 and item["type"] == "W" for item in warnings)
                and not any(item["type"] == "E" for item in warnings),
                extension + " did not lint the valid warning-only buffer: " + json.dumps(warnings))
        require(any(sign["name"] == "ALEWarningSign" and sign["lnum"] == 4
                    for sign in state["warning"]["signs"]),
                extension + " did not place an unused-variable warning")
    require(state["fixed"]["loclist"] == [] and state["fixed"]["signs"] == [],
            extension + " kept stale diagnostics after fixing the unsaved buffer")
    require(state["disk_after_bufferlint"] == broken and source.read_text() == original,
            "Linting rewrote the source file")
    require(not marker.exists(), "Linting executed the edited program")
    require(state["error_sign"] == ">>" and state["warning_sign"] == "!!",
            "Diagnostic markers did not use the configured symbols")
    print("[diagnostics test] " + case.name + " errors, signs, InsertLeave, save, and buffer fixes passed",
          flush=True)


def main():
    with tempfile.TemporaryDirectory(prefix="linux-env-diagnostics-") as temporary:
        root = Path(temporary)
        test_plugin_startup(root)
        for extension in ("c", "cpp", "py"):
            test_diagnostics(root, extension)
        test_diagnostics(root, "py", syntax_error=True)


if __name__ == "__main__":
    main()
