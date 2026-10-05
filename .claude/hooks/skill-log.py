#!/usr/bin/env python3
"""스킬 관련 사실 기록 훅 — 일어난 일만 남긴다. 추측·해석은 하지 않는다.

기록하는 것 (.claude/skill-log.md, git 에서 제외)
  - Skill 도구 호출      : 시각, 스킬 이름
  - Agent 도구 종료      : 시각, 에이전트 설명·종류, 에이전트가 돌려준 보고 원문
  - 작업 종료(Stop)      : 시각, 그 시점 git status --short

하지 않는 것
  - AI 에게 아무것도 돌려주지 않는다(표준 출력 없음) — AI 행동을 바꾸지 않기 위해
  - "어느 수정이 어느 스킬 덕분인가" 같은 연결 짓기 — 사람이 기록을 보고 판단한다
어떤 오류가 나도 조용히 끝낸다(작업을 막지 않는다).
"""

import datetime
import json
import os
import subprocess
import sys


def text_of(value):
    """도구 응답에서 사람이 읽을 글만 꺼낸다. 모르는 모양이면 JSON 그대로."""
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = [text_of(v) for v in value]
        return "\n".join(p for p in parts if p)
    if isinstance(value, dict):
        if value.get("type") == "text" and "text" in value:
            return value["text"]
        for key in ("content", "result", "text", "output"):
            if key in value:
                return text_of(value[key])
        return json.dumps(value, ensure_ascii=False, indent=2)
    return str(value)


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace") or "{}")
    except ValueError:
        return
    root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    log = os.path.join(root, ".claude", "skill-log.md")
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    event = data.get("hook_event_name", "")
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    lines = []

    if event == "PostToolUse" and tool == "Skill":
        lines.append(f"## {now} · 스킬 호출 · `{inp.get('skill', '?')}`")
    elif event == "PostToolUse" and tool in ("Agent", "Task"):
        lines.append(f"## {now} · 에이전트 종료 · {inp.get('description', '')}")
        lines.append(f"- 종류: `{inp.get('subagent_type', '(기본)')}`")
        if inp.get("model"):
            lines.append(f"- 모델 지정: `{inp['model']}`")
        lines.append("- 보고 원문:")
        lines.append("")
        report = text_of(data.get("tool_response")).strip() or "(빈 응답)"
        lines.extend("    " + line for line in report.splitlines())
    elif event == "Stop":
        try:
            st = subprocess.run(["git", "status", "--short"], cwd=root,
                                capture_output=True, text=True, timeout=10).stdout.rstrip()  # 앞 공백은 git 의 상태 표시라 지우지 않는다
        except Exception:
            st = "(git status 실패)"
        lines.append(f"## {now} · 작업 종료 · 바뀐 파일(git status --short)")
        lines.append("")
        lines.extend("    " + line for line in (st or "(바뀐 파일 없음)").splitlines())
    else:
        return

    try:
        os.makedirs(os.path.dirname(log), exist_ok=True)
        new = not os.path.exists(log)
        with open(log, "a", encoding="utf-8") as f:
            if new:
                f.write("# 스킬 기록 — 훅이 자동으로 남긴 사실만 (해석 없음)\n\n")
            f.write("\n".join(lines) + "\n\n")
    except OSError:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
