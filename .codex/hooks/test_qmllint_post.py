"""Run with Python; set QT_BIN_DIR to exercise the real qmllint response parser."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("hook", Path(__file__).with_name("qmllint-post.py"))
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)


class ResponseFileTest(unittest.TestCase):
    def test_literal_path_and_real_qmllint(self):
        tool = hook.find_tool("qmllint")
        with tempfile.TemporaryDirectory(prefix="qml rsp ") as directory:
            root = Path(directory).resolve()
            target = root / "Space Name.qml"
            target.write_text("import QtQuick\nItem {}\n", encoding="utf-8")
            rsp = root / "build/.rcc/qmllint/test.rsp"
            rsp.parent.mkdir(parents=True)
            rsp.write_text("--ignore-settings\n" + target.as_posix() + "\n", encoding="utf-8")
            original_run = hook.run

            def check_run(args, cwd):
                self.assertEqual(len(args), 2)
                self.assertTrue(args[1].startswith("@"), "Must exercise response-file branch")
                lines = Path(args[1][1:]).read_text(encoding="utf-8").splitlines()
                self.assertEqual(lines, ["--ignore-settings", target.as_posix()])
                return original_run(args, cwd) if tool else (0, "")

            with patch.object(hook, "run", side_effect=check_run) as runner:
                code, output = hook.lint(target, root, tool or "qmllint")
                runner.assert_called_once()
                self.assertEqual(code, 0, output)
                if tool:
                    target.write_text("import QtQuick\nItem { invalidHookProperty: 1 }\n", encoding="utf-8")
                    code, output = hook.lint(target, root, tool)
                    self.assertIn("invalidHookProperty", output)
                    self.assertNotIn("Failed to open file", output)


if __name__ == "__main__":
    unittest.main()
