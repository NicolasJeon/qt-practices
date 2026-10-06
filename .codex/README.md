# Codex QML hook (Windows)

This branch includes `.codex/hooks.json` and a PowerShell PostToolUse handler.
After an `apply_patch` edit, it formats changed QML with qmlformat and runs qmllint.
Shell edits and manual editor saves do not trigger this handler.

Use Qt 6.11 or newer for this project's `.qmllint.ini` policy.
Set QT_BIN_DIR to your Qt kit's bin directory before starting Codex if necessary.
The hook also searches PATH, C:/Qt_eval, C:/Qt and ~/Qt.

Start Codex in this trusted clone. Versions with hook support require review and
trust of the hook definition; the documented CLI interface is `/hooks`.
If your client has no hook support or trust interface, files alone do not activate
this hook. Manual validation below only verifies the handler, not automatic loading.

## Manual smoke test (PowerShell, from clone root)

```powershell
@{cwd=(Get-Location).Path; tool_name='apply_patch'; tool_input=@{
  command="*** Begin Patch`n*** Update File: Main.qml`n*** End Patch"
}} | ConvertTo-Json -Depth 4 |
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .codex/hooks/qmllint-post.ps1
```

This formats Main.qml in place. Check `git diff` and `.codex/hook-log.md`.
For automatic verification, ask Codex to edit a QML file through apply_patch and
check that a fresh hook-log entry appears without manually invoking the script.
CMake-generated .rcc/qmllint response files are reused when available in build/.