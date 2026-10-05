#!/usr/bin/env bash
# PostToolUse 훅 — .qml 을 저장하면 자동 포맷하고 린트 결과를 에이전트에 되돌린다.
#
# 이식성 메모 (2026-09-18 수정)
#   이전 판은 jq 와 `$HOME/Qt/6.11.1/gcc_64/bin` 고정 경로에 의존했다. 둘 다 없는
#   머신(예: Windows)에서 훅이 **에러 없이 조용히 exit 0** 해서, 훅이 꺼진 줄
#   모르고 쓰게 됐다. 그래서:
#     - JSON 입출력은 jq 대신 python 으로 한다 (jq 는 기본 설치가 아니다)
#     - Qt bin 은 QT_BIN_DIR → PATH → 흔한 설치 경로 순으로 찾는다
#     - Windows 경로('C:\...')는 cygpath 로 변환하고, .exe 접미사도 본다
#   전제가 빠지면 이제 stderr 로 이유를 남긴다.

PY=$(command -v python3 || command -v python) || {
    echo "qml-check: python 이 없어 훅을 건너뜁니다." >&2
    exit 0
}

# 1) 훅 입력(stdin JSON)에서 대상 파일 경로만 꺼낸다 ------------------------------
f=$("$PY" -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as exc:
    print(f"qml-check: 훅 입력 JSON 을 읽지 못했습니다: {exc}", file=sys.stderr)
    sys.exit(0)
resp = d.get("tool_response") if isinstance(d.get("tool_response"), dict) else {}
inp = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
print(resp.get("filePath") or inp.get("file_path") or "")
')

case "$f" in *.qml) ;; *) exit 0 ;; esac
command -v cygpath >/dev/null 2>&1 && f=$(cygpath -u "$f" 2>/dev/null || echo "$f")
[ -f "$f" ] || exit 0

# 기록 -------------------------------------------------------------------------
# 훅이 한 일을 .claude/hook-log.md 에 사실만 남긴다(git 에서 제외). AI 에게는 아무것도
# 돌려주지 않는다 — 사람이 프롬프트를 돌린 뒤 "훅이 돌았나, 무엇을 봤나" 를 확인하는 용도다.
# 기록이 실패해도 훅은 그대로 진행한다.
LOGROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v cygpath >/dev/null 2>&1 && LOGROOT=$(cygpath -u "$LOGROOT" 2>/dev/null || echo "$LOGROOT")
HOOK_LOG="$LOGROOT/.claude/hook-log.md"
name=$(basename "$f")
hook_log() {  # hook_log <제목> [본문]
    mkdir -p "$(dirname "$HOOK_LOG")" 2>/dev/null || return 0
    [ -f "$HOOK_LOG" ] || printf '# 훅 기록 - 훅이 자동으로 남긴 사실만 (해석 없음)

' >> "$HOOK_LOG" 2>/dev/null
    {
        printf '## %s · %s
' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
        [ -n "${2:-}" ] && { printf '
'; printf '%s
' "$2" | sed 's/^/    /'; }
        printf '
'
    } >> "$HOOK_LOG" 2>/dev/null
    return 0
}

# 2) qmlformat / qmllint 찾기 ----------------------------------------------------
find_qt_tool() {
    local name="$1" cand dir
    for cand in "${QT_BIN_DIR:+$QT_BIN_DIR/$name}" "${QT_BIN_DIR:+$QT_BIN_DIR/$name.exe}"; do
        [ -n "$cand" ] && [ -x "$cand" ] && { printf '%s\n' "$cand"; return 0; }
    done
    cand=$(command -v "$name" 2>/dev/null) && { printf '%s\n' "$cand"; return 0; }
    # 흔한 설치 루트. 버전 역순이라 최신 킷을 먼저 본다.
    for dir in $(ls -d "$HOME"/Qt/6.*/*/bin /c/Qt/6.*/*/bin 2>/dev/null | sort -Vr); do
        for cand in "$dir/$name" "$dir/$name.exe"; do
            [ -x "$cand" ] && { printf '%s\n' "$cand"; return 0; }
        done
    done
    return 1
}

QMLFORMAT=$(find_qt_tool qmlformat) || {
    echo "qml-check: qmlformat 을 찾지 못했습니다. QT_BIN_DIR 를 설정하세요." >&2
    hook_log "$name · 훅 건너뜀" "qmlformat 을 찾지 못했습니다 (QT_BIN_DIR=${QT_BIN_DIR:-미설정}). 포맷·린트를 하지 않았습니다."
    exit 0
}
QMLLINT=$(find_qt_tool qmllint)

# 3) 포맷은 .qmlformat.ini 를 따라 무조건 적용 -----------------------------------
fmt_before=$(cksum < "$f" 2>/dev/null)
"$QMLFORMAT" -i "$f" >/dev/null 2>&1
if [ "$fmt_before" = "$(cksum < "$f" 2>/dev/null)" ]; then fmt="qmlformat: 바뀐 것 없음"; else fmt="qmlformat: 파일을 고쳤음"; fi

[ -n "$QMLLINT" ] || { hook_log "$name · $fmt · qmllint 를 찾지 못해 린트 건너뜀"; exit 0; }

# 4) 가장 가까운 build/ 를 찾는다 (없으면 생략) ---------------------------------
# 루프 종료 조건을 dirname 고정점으로 잡는다. 이전 판은 `[ "$d" != "/" ]` 였는데
# Windows 경로('C:/...')에서는 dirname 이 'C:' 에 머물러 무한 루프가 된다.
BUILD=""
d=$(cd "$(dirname "$f")" && pwd)
while :; do
    [ -d "$d/build" ] && { BUILD="$d/build"; break; }
    parent=$(dirname "$d")
    [ "$parent" = "$d" ] && break
    d="$parent"
done

# 5) 린트한다 --------------------------------------------------------------------
# CMake 프로젝트면 qt_add_qml_module 이 만든 response file 을 써야 한다.
# `-I build` 만으로는 그 파일이 **자기 모듈 소속**이라는 것을 몰라서, 같은 모듈에
# C++ 로 등록된 타입을 못 찾고 가짜 import 에러를 뱉는다 (findings §26-4 실측).
out=""
if [ -n "$BUILD" ]; then
    RSP="$(dirname "$0")/qmllint-rsp.py"
    if [ -f "$RSP" ]; then
        out=$("$PY" "$RSP" "$BUILD" "$f" "$QMLLINT" 2>/dev/null)
        rc=$?
    else
        rc=2
    fi
    # rsp 를 못 찾았으면(해당 파일이 아직 QML_FILES 에 없는 등) 평소 방식으로.
    [ "$rc" -ne 0 ] && out=$("$QMLLINT" -I "$BUILD" "$f" 2>&1)
else
    out=$("$QMLLINT" "$f" 2>&1)
fi
if [ -z "$out" ]; then
    hook_log "$name · $fmt · qmllint 경고 없음"
    exit 0
fi
hook_log "$name · $fmt · qmllint 지적 $(printf '%s
' "$out" | grep -cE '^(Warning|Error):')건 (아래 내용을 AI 에게 돌려줌)" "$out"
# ensure_ascii=True(기본)로 내보낸다. Windows 콘솔 기본 인코딩(cp949 등)에서는
# 한글·em dash 를 그대로 쓰면 UnicodeEncodeError 로 훅이 죽는다. \uXXXX 이스케이프는
# 유효한 JSON 이고 Claude Code 가 되돌려 읽는다.
printf '%s' "$out" | "$PY" -c '
import json, sys
out = sys.stdin.buffer.read().decode("utf-8", "replace")
sys.stdout.write(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "qmllint 결과 - 고칠 것:\n" + out,
    }
}) + "\n")
'
exit 0
