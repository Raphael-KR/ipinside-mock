# IPinside Mock Project Root Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all tracked IPinside Mock development files under `/Users/raphael/Playground/ipinside-mock` while preserving the installed app and user runtime data in their macOS-standard locations.

**Architecture:** Treat `/Users/raphael/ipinside-mock-repo` as the canonical Git repository and move it intact to the new root. Keep the legacy experiment directory as a temporary rollback copy until source-path fixes, a clean build, HTTPS behavior, process cleanup, Git integrity, and runtime-data checksums are verified.

**Tech Stack:** macOS, zsh, Git, Bash, Swift 5.5+, Cocoa, Network.framework, Python 3, macOS Keychain

## Global Constraints

- Final project root: `/Users/raphael/Playground/ipinside-mock`.
- Installed application remains at `/Applications/IPinsideMock.app`.
- Runtime data remains at `/Users/raphael/Library/Application Support/IPinsideMock`.
- Never add `captured.json`, `*.crt`, `*.key`, `*.pem`, `*.app`, or `AppIcon.icns` to Git.
- Do not delete the legacy backup until all automated gates pass and any
  approved manual-check verification waiver is recorded.
- Do not change the app bundle identifier, response protocol, capture format, or setup behavior.

---

### Task 1: Record preflight state and relocate the canonical repository

**Files:**
- Move: `/Users/raphael/ipinside-mock-repo` to `/Users/raphael/Playground/ipinside-mock`
- Temporarily move: `/Users/raphael/ipinside-mock` to `/Users/raphael/ipinside-mock.legacy-backup-20260711`
- Create: `/tmp/ipinside-mock-runtime-before.sha256`
- Create: `/tmp/ipinside-mock-legacy-files.txt`

**Interfaces:**
- Consumes: canonical Git repository at `/Users/raphael/ipinside-mock-repo`; runtime data at `/Users/raphael/Library/Application Support/IPinsideMock`
- Produces: canonical repository at `/Users/raphael/Playground/ipinside-mock`; rollback copy at `/Users/raphael/ipinside-mock.legacy-backup-20260711`

- [ ] **Step 1: Verify all source and destination paths before moving anything**

Run:

```bash
test -d /Users/raphael/ipinside-mock
test -d /Users/raphael/ipinside-mock-repo/.git
test ! -e /Users/raphael/Playground/ipinside-mock
test ! -e /Users/raphael/ipinside-mock.legacy-backup-20260711
git -C /Users/raphael/ipinside-mock-repo status --short --branch
git -C /Users/raphael/ipinside-mock-repo remote get-url origin
```

Expected:

```text
## main...origin/main [ahead 2]
https://github.com/Raphael-KR/ipinside-mock.git
```

If either destination already exists or the Git worktree has changes other than the committed design document, stop before moving directories.

- [ ] **Step 2: Record runtime-data checksums and the complete legacy inventory**

Run:

```bash
find '/Users/raphael/Library/Application Support/IPinsideMock' \
  -maxdepth 1 -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  > /tmp/ipinside-mock-runtime-before.sha256

find /Users/raphael/ipinside-mock -mindepth 1 -print \
  | sort \
  > /tmp/ipinside-mock-legacy-files.txt

cat /tmp/ipinside-mock-runtime-before.sha256
```

Expected: checksums for `captured.json`, `interezen.crt`, and `interezen.key` appear. The command must not modify those files.

- [ ] **Step 3: Stop the installed app and confirm port 21300 is free**

Run:

```bash
pkill -x IPinsideMock 2>/dev/null || true
sleep 3
test -z "$(lsof -tiTCP:21300 -sTCP:LISTEN 2>/dev/null)"
test -z "$(pgrep -f '[i]pinside_mock_server.py' 2>/dev/null)"
```

Expected: both `test` commands exit successfully and print nothing.

- [ ] **Step 4: Move the legacy directory to a rollback name**

Run:

```bash
mv /Users/raphael/ipinside-mock \
  /Users/raphael/ipinside-mock.legacy-backup-20260711
```

Expected: the backup exists and the old project path does not.

```bash
test -d /Users/raphael/ipinside-mock.legacy-backup-20260711
test ! -e /Users/raphael/ipinside-mock
```

- [ ] **Step 5: Move the canonical Git repository to the approved root**

Run:

```bash
mkdir -p /Users/raphael/Playground
mv /Users/raphael/ipinside-mock-repo \
  /Users/raphael/Playground/ipinside-mock
```

Expected:

```bash
test -d /Users/raphael/Playground/ipinside-mock/.git
test ! -e /Users/raphael/ipinside-mock-repo
git -C /Users/raphael/Playground/ipinside-mock status --short --branch
```

The branch output remains `main...origin/main [ahead 2]`.

---

### Task 2: Make icon generation relative to the project root

**Files:**
- Modify: `/Users/raphael/Playground/ipinside-mock/generate_icon.swift:155-162`
- Generated, ignored: `/Users/raphael/Playground/ipinside-mock/AppIcon.icns`

**Interfaces:**
- Consumes: `CommandLine.arguments[0]`, the path used to invoke `generate_icon.swift`
- Produces: `AppIcon.icns` beside `generate_icon.swift`, regardless of the caller's current directory

- [ ] **Step 1: Run the existing generator from outside the project to demonstrate the hard-coded-path failure**

Run:

```bash
rm -f /Users/raphael/Playground/ipinside-mock/AppIcon.icns
cd /tmp
swift /Users/raphael/Playground/ipinside-mock/generate_icon.swift
test -f /Users/raphael/Playground/ipinside-mock/AppIcon.icns
```

Expected: the final `test` fails because the current code writes to the obsolete `/Users/raphael/ipinside-mock/AppIcon.icns` path.

- [ ] **Step 2: Replace the hard-coded output path with a script-relative path**

Modify the conversion block to exactly:

```swift
// Convert to .icns beside this script so builds are location-independent.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent()
let outputPath = projectRoot.appendingPathComponent("AppIcon.icns").path

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
print("Icon saved to: \(outputPath)")
```

- [ ] **Step 3: Run the generator from `/tmp` and verify its output**

Run:

```bash
cd /tmp
swift /Users/raphael/Playground/ipinside-mock/generate_icon.swift
test -s /Users/raphael/Playground/ipinside-mock/AppIcon.icns
file /Users/raphael/Playground/ipinside-mock/AppIcon.icns
git -C /Users/raphael/Playground/ipinside-mock status --short --ignored \
  | grep '!! AppIcon.icns'
```

Expected: `file` reports `Mac OS X icon`, and Git reports `!! AppIcon.icns`.

---

### Task 3: Make `build.sh` work from a clean clone layout

**Files:**
- Modify: `/Users/raphael/Playground/ipinside-mock/build.sh:5-25`
- Consume: `/Users/raphael/Playground/ipinside-mock/src/main.swift`
- Generated, ignored: `/Users/raphael/Playground/ipinside-mock/IPinsideMock.app`

**Interfaces:**
- Consumes: `src/main.swift`, `generate_icon.swift`, and optionally an existing `AppIcon.icns`
- Produces: project-local `IPinsideMock.app` and installed `/Applications/IPinsideMock.app`

- [ ] **Step 1: Demonstrate that the current source path is invalid**

Run:

```bash
test ! -f /Users/raphael/Playground/ipinside-mock/IPinsideMock/main.swift
test -f /Users/raphael/Playground/ipinside-mock/src/main.swift
rg -n 'IPinsideMock/main.swift' /Users/raphael/Playground/ipinside-mock/build.sh
```

Expected: both file tests pass and `rg` shows the obsolete path on line 18.

- [ ] **Step 2: Define source and icon paths and generate a missing icon automatically**

Immediately after `SCRIPT_DIR`, add:

```bash
SOURCE_FILE="$SCRIPT_DIR/src/main.swift"
ICON_FILE="$SCRIPT_DIR/AppIcon.icns"
```

Immediately before `swiftc`, add:

```bash
if [[ ! -f "$ICON_FILE" ]]; then
    echo "아이콘 생성 중..."
    swift "$SCRIPT_DIR/generate_icon.swift"
fi
```

Replace the Swift source argument and icon copy command with:

```bash
    "$SOURCE_FILE"
```

and:

```bash
cp "$ICON_FILE" "$CONTENTS/Resources/"
```

- [ ] **Step 3: Validate the shell script syntax**

Run:

```bash
bash -n /Users/raphael/Playground/ipinside-mock/build.sh
```

Expected: exit status 0 and no output.

- [ ] **Step 4: Prove a build regenerates the ignored icon from scratch**

Run:

```bash
cd /Users/raphael/Playground/ipinside-mock
rm -f AppIcon.icns
rm -rf IPinsideMock.app
./build.sh
```

Expected output includes:

```text
빌드 중...
아이콘 생성 중...
설치 중...
완료! /Applications/IPinsideMock.app 에 설치되었습니다.
```

- [ ] **Step 5: Verify the project-local and installed app bundles**

Run:

```bash
test -x /Users/raphael/Playground/ipinside-mock/IPinsideMock.app/Contents/MacOS/IPinsideMock
test -s /Users/raphael/Playground/ipinside-mock/IPinsideMock.app/Contents/Resources/AppIcon.icns
test -x /Applications/IPinsideMock.app/Contents/MacOS/IPinsideMock
test -s /Applications/IPinsideMock.app/Contents/Resources/AppIcon.icns
plutil -lint /Applications/IPinsideMock.app/Contents/Info.plist
```

Expected: every `test` succeeds and `plutil` reports `OK`.

- [ ] **Step 6: Commit the location-independent build fixes**

Run:

```bash
cd /Users/raphael/Playground/ipinside-mock
git diff --check
git add build.sh generate_icon.swift
git commit -m "build: make project paths location independent"
```

Expected: one commit containing only `build.sh` and `generate_icon.swift`.

---

### Task 4: Verify runtime behavior and process cleanup

**Files:**
- Execute: `/Applications/IPinsideMock.app`
- Read only: `/Users/raphael/Library/Application Support/IPinsideMock/captured.json`
- Read only: `/Users/raphael/Library/Application Support/IPinsideMock/interezen.crt`
- Read only: `/Users/raphael/Library/Application Support/IPinsideMock/interezen.key`

**Interfaces:**
- Consumes: installed app plus existing captured response and TLS material
- Produces: HTTPS JSONP response on `127.0.0.1:21300` only while the menu item reports the server is running

- [ ] **Step 1: Confirm runtime data was not changed by relocation or build**

Run:

```bash
find '/Users/raphael/Library/Application Support/IPinsideMock' \
  -maxdepth 1 -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  > /tmp/ipinside-mock-runtime-after-build.sha256

diff -u /tmp/ipinside-mock-runtime-before.sha256 \
  /tmp/ipinside-mock-runtime-after-build.sha256
```

Expected: `diff` exits 0 with no output.

- [ ] **Step 2: Launch the app and start the server from the menu bar**

Run:

```bash
open /Applications/IPinsideMock.app
```

Then click the menu bar `IP` item and choose `서버 시작`.

Expected: the menu bar indicator turns green and the status item reports the server is running.

- [ ] **Step 3: Verify the listener and JSONP response**

Run:

```bash
lsof -nP -iTCP:21300 -sTCP:LISTEN
response="$(curl -fsS \
  'https://127.0.0.1:21300/?t=V&value=3.0.0.1:::::::::::::::::&callback=%20')"
printf '%s\n' "$response" | grep '^ ({"result":"I"'
```

Expected: Python listens only on `localhost:21300`, and the response begins with a space followed by `({"result":"I"`.

- [ ] **Step 4: Verify browser-facing behavior with IBK**

Open the IBK business banking page and reach the flow that performs the agent check:

```text
https://kiup.ibk.co.kr/uib/jsp/index.jsp
```

Expected: no `Agent가 설치되어 있지 않다` warning appears and the page advances beyond `처리중입니다. 잠시만 기다려 주세요`.

#### 검증 유예 (Verification waiver)

The authenticated IBK agent-check flow was not re-run during consolidation
because it requires account authentication and could alter account state. The
user explicitly approved treating this check as a post-consolidation manual
acceptance check.

Backup deletion was approved based on successful local loopback HTTPS/JSONP
response validation, successful process-cleanup validation, unchanged
`src/main.swift`, unchanged runtime-data checksums, and the user's prior
successful IBK use. This waiver applies only to this consolidation run and does
not claim that the authenticated IBK flow passed.

- [ ] **Step 5: Quit the menu bar app and verify child cleanup**

Choose `종료` from the app's menu, wait three seconds, then run:

```bash
sleep 3
test -z "$(lsof -tiTCP:21300 -sTCP:LISTEN 2>/dev/null)"
test -z "$(pgrep -f '[i]pinside_mock_server.py' 2>/dev/null)"
```

Expected: both tests exit 0 and no mock Python process remains.

---

### Task 5: Audit secrets, remove the rollback copy, and publish the path fixes

**Files:**
- Delete after verification: `/Users/raphael/ipinside-mock.legacy-backup-20260711`
- Verify: `/Users/raphael/Playground/ipinside-mock/.gitignore`
- Verify: `/Users/raphael/Playground/ipinside-mock/docs/superpowers/specs/2026-07-11-project-root-consolidation-design.md`
- Verify: `/Users/raphael/Playground/ipinside-mock/docs/superpowers/plans/2026-07-11-project-root-consolidation.md`

**Interfaces:**
- Consumes: successful Tasks 1-4 and the legacy inventory
- Produces: one canonical local project root synchronized to GitHub, with no obsolete project directories

- [ ] **Step 1: Verify no private or generated files are tracked**

Run:

```bash
cd /Users/raphael/Playground/ipinside-mock
git ls-files \
  | rg '(^|/)(captured\.json|AppIcon\.icns|.*\.(crt|key|pem)|.*\.app(/|$))' \
  && exit 1 || true
git status --short --ignored \
  | rg '!! (AppIcon\.icns|IPinsideMock\.app/)'
```

Expected: `git ls-files` finds nothing; the generated icon and app bundle appear as ignored.

- [ ] **Step 2: Review files that exist only in the legacy backup**

Run:

```bash
find /Users/raphael/ipinside-mock.legacy-backup-20260711 \
  -mindepth 1 -maxdepth 2 -print \
  | sort
```

Expected unique legacy items are experimental or generated artifacts such as:

```text
mock_server.py
start.sh
stop.sh
interezen.crt
interezen.key
server.crt
server.key
AppIcon.icns
IPinsideMock.app
```

Before deletion, confirm the runtime copies of `captured.json`, `interezen.crt`, and `interezen.key` still match `/tmp/ipinside-mock-runtime-before.sha256`.

- [ ] **Step 3: Delete the verified rollback copy**

Run only after the automated gates in Tasks 1-4 and Steps 1-2 of this task pass,
with the approved authenticated-IBK manual-check waiver recorded:

```bash
rm -rf /Users/raphael/ipinside-mock.legacy-backup-20260711
```

Expected:

```bash
test ! -e /Users/raphael/ipinside-mock.legacy-backup-20260711
test ! -e /Users/raphael/ipinside-mock
test ! -e /Users/raphael/ipinside-mock-repo
test -d /Users/raphael/Playground/ipinside-mock/.git
```

- [ ] **Step 4: Run final Git and runtime-data checks**

Run:

```bash
cd /Users/raphael/Playground/ipinside-mock
git diff --check
git status --short --branch
git remote -v

find '/Users/raphael/Library/Application Support/IPinsideMock' \
  -maxdepth 1 -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  > /tmp/ipinside-mock-runtime-final.sha256

diff -u /tmp/ipinside-mock-runtime-before.sha256 \
  /tmp/ipinside-mock-runtime-final.sha256
```

Expected: the worktree is clean except that `main` is ahead of `origin/main`; the origin URLs are unchanged; runtime checksum diff is empty.

- [ ] **Step 5: Push the committed design, plan, and build fixes**

Run:

```bash
cd /Users/raphael/Playground/ipinside-mock
git log --oneline origin/main..HEAD
git push origin main
git status --short --branch
```

Expected: the log contains the design commit, plan commit, and path-fix commit; push succeeds; final status is:

```text
## main...origin/main
```
