#!/usr/bin/env bash
# 스킬 관련 사실 기록 훅 — 실제 일은 skill-log.py 가 한다. python 을 찾아 넘길 뿐.
# 어떤 경우에도 0 으로 끝낸다(작업을 막지 않는다). AI 에게는 아무것도 출력하지 않는다.
PY=$(command -v python3 || command -v python) || exit 0
"$PY" "$(dirname "$0")/skill-log.py" >/dev/null 2>&1
exit 0
