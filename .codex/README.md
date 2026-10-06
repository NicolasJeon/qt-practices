# Codex QML hook (Windows / macOS / Linux)

Requires Python 3.8+ (standard library only) and Qt 6.11+.
Windows: make `python` available in PATH. macOS/Linux: use `python3`.
Set QT_BIN_DIR to the Qt kit's bin directory before starting Codex to select a kit.
Otherwise the handler searches PATH and common Qt installation directories.

PostToolUse handles apply_patch edits, formats changed QML and returns lint
warnings to Codex. Manual saves and shell edits do not trigger this handler.
CMake response files in build/**/.rcc/qmllint are reused when available.
The hook log is `.codex/hook-log.md` (ignored by Git).

Start Codex in the clone or a subdirectory. The launcher finds the script by
walking parent directories; there are no machine-specific repository paths.
Codex must support hooks and trust the project/hook definition before automatic
execution. The documented CLI review interface is `/hooks`, when available.
If your client does not support it, files alone do not activate the hook.

To test the handler manually, pipe a PostToolUse JSON event with cwd,
tool_name=apply_patch and tool_input.command containing patch headers into:

    python .codex/hooks/qmllint-post.py

Use python3 on macOS/Linux. This formats the referenced QML files in place.
Manual execution verifies the script only. To verify automatic execution,
make a Codex apply_patch QML edit and check for a fresh hook-log entry.