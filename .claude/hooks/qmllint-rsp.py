#!/usr/bin/env python3
"""CMake 프로젝트에서 .qml 한 파일만 **올바르게** 린트한다.

왜 필요한가
    `qmllint Foo.qml` 이나 `qmllint -I build Foo.qml` 은 그 파일이 **어느 모듈에
    속하는지** 모른다. 그래서 같은 모듈에 C++ 로 등록된 타입(예: QAbstractListModel
    파생 클래스)을 못 찾고, 진짜 문제 대신 가짜 import 에러를 뱉는다.
    (실측 2026-10-05: 같은 파일을 `-I build` 로 린트하면 `[import]` 1건,
     `all_qmllint` 타겟으로 돌리면 `[missing-property]` 2건 — findings §26-4)

어떻게 고치나
    `qt_add_qml_module` 이 build/**/.rcc/qmllint/<target>.rsp 를 만든다. 그 안에
    import 경로와 `--resource <qrc>` 가 들어 있어 모듈 소속이 해결된다.
    여기서 **파일 목록만 바꿔 끼우면** 한 파일만 올바른 맥락으로 린트할 수 있다.
    (전체를 보는 `all_qmllint` 는 저장마다 돌리기엔 느리다.)

사용
    python qmllint-rsp.py <build_dir> <qml_file> [qmllint 경로]

반환
    0  린트를 돌렸다 (결과는 stdout)
    2  이 파일을 담은 .rsp 가 없다 → 호출한 쪽이 평소 방식으로 넘어가면 된다
"""
import glob
import os
import subprocess
import sys
import tempfile


def same_path(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def main():
    if len(sys.argv) < 3:
        return 2
    build, target = sys.argv[1], sys.argv[2]
    qmllint = sys.argv[3] if len(sys.argv) > 3 else 'qmllint'
    if not os.path.isdir(build):
        return 2

    # *_json.rsp 는 JSON 출력용, *_module.rsp 는 모듈 단위라 제외한다.
    rsps = [p for p in glob.glob(os.path.join(build, '**', '.rcc', 'qmllint', '*.rsp'),
                                 recursive=True)
            if not p.endswith(('_json.rsp', '_module.rsp'))]

    for rsp in rsps:
        try:
            toks = [t.strip() for t in open(rsp, encoding='utf-8').read().split('\n') if t.strip()]
        except OSError:
            continue
        # 끝에 붙은 .qml 들이 그 타겟의 파일 목록이다. 나머지는 전부 플래그.
        if not any(t.lower().endswith('.qml') and same_path(t, target) for t in toks):
            continue
        flags = [t for t in toks if not t.lower().endswith('.qml')]

        fd, tmp = tempfile.mkstemp(suffix='.rsp', text=True)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as fh:
                fh.write('\n'.join(flags + [os.path.abspath(target).replace('\\', '/')]))
            res = subprocess.run([qmllint, '@' + tmp], capture_output=True, text=True)
            sys.stdout.write((res.stdout or '') + (res.stderr or ''))
        except OSError:
            return 2
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        return 0

    return 2


if __name__ == '__main__':
    sys.exit(main())
