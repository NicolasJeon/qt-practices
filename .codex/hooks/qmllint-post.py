"""Codex PostToolUse QML formatter/linter; Python 3 standard library only."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def run(args, cwd):
    result = subprocess.run([str(a) for a in args], cwd=cwd, capture_output=True,
                            encoding="utf-8", errors="replace", timeout=20)
    return result.returncode, (result.stdout + result.stderr).strip()


def version(path):
    return tuple(int(n) for n in re.findall(r"\d+", str(path.parent.parent.parent.name)))


def find_tool(name):
    executable = name + (".exe" if os.name == "nt" else "")
    if os.environ.get("QT_BIN_DIR"):
        path = Path(os.environ["QT_BIN_DIR"]) / executable
        if path.is_file():
            return path
        raise RuntimeError(f"QT_BIN_DIR does not contain {executable}")
    on_path = shutil.which(executable)
    if on_path:
        return Path(on_path)
    roots = [Path.home() / "Qt", Path("C:/Qt_eval"), Path("C:/Qt"),
             Path("/opt/Qt"), Path("/usr/lib/qt6"), Path("/usr/lib64/qt6"),
             Path("/opt/homebrew/opt/qt"), Path("/usr/local/opt/qt")]
    candidates = []
    for root in roots:
        candidates.extend(root.glob(f"6.*/*/bin/{executable}"))
        direct = root / "bin" / executable
        if direct.is_file():
            candidates.append(direct)
    return next(iter(sorted(candidates, key=version, reverse=True)), None)


def changed_files(event, root):
    data = event.get("tool_input") or {}
    response = event.get("tool_response") or {}
    patch = data if isinstance(data, str) else data.get("command", data.get("input", ""))
    paths = re.findall(r"^\*\*\* (?:Add File|Update File|Move to): (.+)$", patch, re.M)
    if isinstance(data, dict) and data.get("file_path"):
        paths.append(data["file_path"])
    if isinstance(response, dict) and response.get("filePath"):
        paths.append(response["filePath"])
    cwd = Path(event.get("cwd") or root)
    files = set()
    for value in paths:
        path = (cwd / value.strip()).resolve()
        if path.suffix.lower() == ".qml" and path.is_file() and root in path.parents:
            files.add(path)
    return sorted(files)


def lint(file, root, tool):
    build = next((p / "build" for p in [file.parent, *file.parent.parents]
                  if (p == root or root in p.parents) and (p / "build").is_dir()), None)
    if build:
        for rsp in sorted(build.glob("**/.rcc/qmllint/*.rsp")):
            if rsp.name.endswith(("_json.rsp", "_module.rsp")):
                continue
            tokens = [s.strip() for s in rsp.read_text(encoding="utf-8").splitlines() if s.strip()]
            def qml_path(token):
                return token.strip('"').lower().endswith(".qml")
            if not any((root / t.strip('"')).resolve() == file for t in tokens if qml_path(t)):
                continue
            flags = [t for t in tokens if not qml_path(t)]
            with tempfile.TemporaryDirectory(prefix="codex-qmllint-") as directory:
                temporary = Path(directory) / "file.rsp"
                temporary.write_text("\n".join(flags + [json.dumps(file.as_posix())]), encoding="utf-8")
                return run([tool, "@" + str(temporary)], root)
    return run([tool, *(["-I", build] if build else []), file], root)


def main():
    root = Path(__file__).resolve().parents[2]
    feedback = []
    try:
        event = json.load(sys.stdin)
        files = changed_files(event, root)
        if not files:
            return
        formatter, linter = find_tool("qmlformat"), find_tool("qmllint")
        if not formatter or not linter:
            raise RuntimeError("Qt tools missing; set QT_BIN_DIR to your Qt kit's bin directory")
        code, tool_version = run([linter, "--version"], root)
        match = re.search(r"(\d+)\.(\d+)", tool_version)
        if code or not match or tuple(map(int, match.groups())) < (6, 11):
            raise RuntimeError(f"This project's lint policy requires Qt 6.11+: {tool_version}")
        for file in files:
            details = []
            try:
                before = file.read_bytes()
                code, output = run([formatter, "-i", file], root)
                details.append(f"qmlformat exit {code}: {output}" if code else
                               "qmlformat: " + ("formatted" if file.read_bytes() != before else "unchanged"))
                if code:
                    feedback.append(f"{file}: qmlformat failed: {output}")
                code, output = lint(file, root, linter)
                details.append(f"qmllint exit {code}: {output}" if code or output else "qmllint: no warnings")
                if code or output:
                    feedback.append(f"{file}: qmllint (exit {code})\n{output}")
            except Exception as exc:
                details.append(f"QML hook failed: {exc}")
                feedback.append(details[-1])
            with (root / ".codex/hook-log.md").open("a", encoding="utf-8") as log:
                log.write(f"\n## {datetime.datetime.now().isoformat(timespec='seconds')} - {file.relative_to(root)}\n")
                log.write("\n".join(details) + "\n")
    except Exception as exc:
        feedback.append(f"QML hook could not run: {exc}")
    if feedback:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                         "additionalContext": "\n".join(feedback)}}))


if __name__ == "__main__":
    main()
