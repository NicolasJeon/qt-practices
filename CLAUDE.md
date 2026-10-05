# 장비 모니터링 앱 (Qt 6 / Qt Quick)

## 대상
Qt 6 / Qt Quick(QML) 표준 CMake 프로젝트 — `qt_add_executable` + `qt_add_qml_module`,
C++ 모델(`EventLogModel`) 포함.

## 이 프로젝트에서 지켜야 할 규칙
- **QML 코드를 쓰거나 고칠 때는 항상 `qt-qml` 스킬을 먼저 호출한다.**
- Qt API 사실(프로퍼티·기본값·단위·since-version)은 **추측하지 않는다.** 아래 "조회" 참고.
- Qt 소스 트리(`Src/`) 전체는 **절대 훑지 않는다.** 디렉터리를 통째로 읽지 말고
  한 번에 한 파일만 지정한다.
- `.qml` 파일을 쓰거나 고친 뒤에는 **반드시** `qt-qml-review` 스킬을 호출한다.
- `.cpp`/`.h` 파일을 쓰거나 고친 뒤에는 **반드시** `qt-cpp-review` 스킬을 호출한다.
- **QML 파일을 새로 만들면 `CMakeLists.txt` 의 `QML_FILES` 에 반드시 추가한다.**
  빠뜨리면 빌드는 되지만 런타임에 모듈에서 찾지 못한다.
- qmllint 경고는 **내가 만든 것이든 원래 있던 것이든 전부 고친다.** 남겨두지 않는다.
- CMake 구성은 `qt-cmake-project` 스킬 기준. qmake-ism(`qt5_*` 매크로, `.pro`) 금지.
- 테스트는 Qt Quick Test(`tst_*.qml`, `TestCase`/`SignalSpy`/`tryCompare`).
- 스킬/에이전트 출력은 항상 **사람이 검증한다.** 생성 결과를 그대로 커밋하지 않는다.

> 포맷·린트는 **훅이 저장할 때마다 자동으로 돌린다**
> ([.claude/hooks/qml-check.sh](.claude/hooks/qml-check.sh)) — 직접 챙기지 않아도 된다.

## 조회 — 로컬 먼저, MCP 다음

Qt API 사실이 필요하면 **먼저 `python tools/qdoc.py`** 로 로컬 `.qch` 색인을 조회한다
(사용법은 `python tools/qdoc.py --help`). Qt 설치 폴더를 `Glob`·`Grep` 으로 훑지 않는다.
로컬에 없거나 버전이 의심되면 `qt-docs` MCP 로 교차 확인하고 **출처 파일명을 남긴다.**
MCP 의 `version` 에는 `6.11.0` 과 `6.8.7` 만 있다 — 설치된 Qt 와 가까운 쪽을 고른다.

## 빌드

- **`qmllint` 는 직접 부르지 말고 `all_qmllint` 타겟을 쓴다.** `qt_add_qml_module` 이
  import 경로가 해결된 response file 을 넣어주므로, 직접 부르면 가짜 import 경고가 난다.
- 빌드 폴더가 이미 있으면(IDE 가 만든 것 포함) 그것을 `cmake --build <폴더>` 로 쓴다.
  새로 구성할 때는 설치된 Qt 의 경로를 `CMAKE_PREFIX_PATH` 로 준다.
- **MinGW 컴파일러는 자기 `bin` 이 `PATH` 에 있어야 실행된다**(DLL). 없으면 configure 가
  `g++ - broken` 으로 죽는다.
- 테스트 실행은 `qmltestrunner -input tst_X.qml -import . -o result.txt,txt`.
  **Windows 에서는 `-o` 없이는 결과가 화면에 안 나온다**(GUI 서브시스템 바이너리).
