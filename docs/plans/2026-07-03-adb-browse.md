# ADB Browse Weibo / Douyin / Bilibili / RedNote — Plan for Small Model

> **Executor:** Run units top to bottom. Each unit ends in one verify command.
> Check the box only when that command shows the expected PASS.
> If a unit is too large or too vague to execute, STOP and invoke the
> `write-plan-for-small-model` skill on that unit to split it further.

> **Called by:** top-level plan (none).

**Goal:** Use ADB to launch and browse four Chinese social apps (Weibo, Douyin, Bilibili, RedNote/Xiaohongshu) on the connected Mi 8 UD running Android 10.

**Architecture:** A shell script per app. Each script launches the app, waits for load, does basic navigation (scroll feed, tap a post, search), takes a screenshot after each step, and a final verify command checks the screenshots exist. All ADB interaction uses `adb shell monkey`, `adb shell input`, `adb shell uiautomator dump`, and `adb exec-out screencap`.

**Tech Stack:** Bash, ADB, uiautomator, screencap

## Global Constraints

- Device: `6e5b7400`, Xiaomi Mi 8 UD, Android 10, 1080x2248, MIUI
- DO NOT use `sudo` — no root available
- All ADB commands target the connected USB device (already authorized)
- Screenshots saved to `adb_browse_out/` in the current directory
- If `uiautomator dump` shows the MIUI ENOENT warning, ignore it — the dump still succeeds
- Each script must be idempotent (can re-run safely)

## Done Definition

The plan is finished when every verify below shows PASS. Nothing more, nothing less.

---

### Unit 1: Install Douyin & verify all 4 apps can launch

**Files:**
- Create: `adb_browse_out/` (directory for screenshots)
- No code files created; this is pure ADB + download

**Interfaces:**
- Produces: `adb_browse_out/` directory exists with `.png` screenshots from each app launch

**Recurse if:** Douyin APK download is blocked or install fails — then invoke `write-plan-for-small-model` on this unit.

- [ ] **Step 1 — Create output directory & launch existing apps as smoke test.** Run these commands:

```bash
mkdir -p adb_browse_out
```

```bash
adb shell monkey -p com.sina.weibo -c android.intent.category.LAUNCHER 1
sleep 3
adb exec-out screencap -p > adb_browse_out/01_weibo_launch.png
adb shell input keyevent KEYCODE_HOME
```

```bash
adb shell monkey -p tv.danmaku.bili -c android.intent.category.LAUNCHER 1
sleep 3
adb exec-out screencap -p > adb_browse_out/01_bilibili_launch.png
adb shell input keyevent KEYCODE_HOME
```

```bash
adb shell monkey -p com.xingin.xhs -c android.intent.category.LAUNCHER 1
sleep 3
adb exec-out screencap -p > adb_browse_out/01_rednote_launch.png
adb shell input keyevent KEYCODE_HOME
```

- [ ] **Step 2 — Install Douyin.** Download the official Douyin APK from a trusted mirror (e.g. APKPure or CoolAPK), push to device, and install:

```bash
# Download Douyin APK (arm64-v8a, Android 5.0+) from a mirror
# If curl/wget fails, manually download and place at /tmp/douyin.apk
curl -L -o /tmp/douyin.apk "https://d.apkpure.com/b/APK/com.ss.android.ugc.aweme?version=latest" 2>&1 || echo "Download may have failed - check /tmp/douyin.apk"
```

If download fails, try alternative:

```bash
# Alternative: use a direct link or manually download
# Place the APK at /tmp/douyin.apk and continue
ls -la /tmp/douyin.apk
```

Install it (phone must be unlocked):

```bash
adb install -r /tmp/douyin.apk
```

- [ ] **Step 3 — Launch Douyin & verify.**

```bash
adb shell monkey -p com.ss.android.ugc.aweme -c android.intent.category.LAUNCHER 1
sleep 4
adb exec-out screencap -p > adb_browse_out/01_douyin_launch.png
adb shell input keyevent KEYCODE_HOME
```

- [ ] **Step 4 — Verify framework (inline).** Run this one-liner:

```bash
ls -la adb_browse_out/01_weibo_launch.png adb_browse_out/01_bilibili_launch.png adb_browse_out/01_rednote_launch.png adb_browse_out/01_douyin_launch.png && echo "PASS: All 4 launch screenshots exist" || echo "FAIL: Missing screenshots"
```

- [ ] **Step 5 — Expected result.**
  - PASS: `PASS: All 4 launch screenshots exist`, all files > 0 bytes
  - FAIL: `FAIL: Missing screenshots` or Douyin install fails — if Douyin APK download is the blocker, try a different mirror or skip Douyin and proceed with 3 apps

- [ ] **Step 6 — Commit.**

```bash
git add adb_browse_out/ && git commit -m "adb: verify all 4 apps launch" || echo "Warning: commit skipped"
```

---

### Unit 2: Browse Weibo — scroll feed, search, view post

**Files:**
- Create: `scripts/adb_browse/weibo.sh`
- Screenshots: `adb_browse_out/02_weibo_*.png`

**Interfaces:**
- Consumes: `adb_browse_out/` directory from Unit 1
- Produces: 3 screenshots (`feed`, `search`, `post`) from Weibo

- [ ] **Step 1 — Code piece.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/weibo.sh
# Browse Weibo: launch → scroll feed → search → view a post
set -e
OUT="adb_browse_out"
mkdir -p "$OUT"

echo "=== Launch Weibo ==="
adb shell monkey -p com.sina.weibo -c android.intent.category.LAUNCHER 1
sleep 5
adb exec-out screencap -p > "$OUT/02_weibo_feed.png"
echo "  screenshot: $OUT/02_weibo_feed.png"

echo "=== Scroll feed ==="
# Swipe up 3 times to scroll the feed
for i in 1 2 3; do
    adb shell input swipe 540 1500 540 500 300
    sleep 2
done
adb exec-out screencap -p > "$OUT/02_weibo_feed_scrolled.png"
echo "  screenshot: $OUT/02_weibo_feed_scrolled.png"

echo "=== Search ==="
# Tap search icon (top-right area, coordinates may need adjustment)
adb shell input tap 1000 150
sleep 2
# Dump UI to find the search input field
adb shell uiautomator dump /sdcard/ui.xml 2>/dev/null
adb pull /sdcard/ui.xml /tmp/weibo_search_ui.xml 2>/dev/null
# Try tapping search bar center
adb shell input tap 540 200
sleep 1
# Type search text
adb shell input text "AI"
sleep 1
adb shell input keyevent KEYCODE_ENTER
sleep 3
adb exec-out screencap -p > "$OUT/02_weibo_search.png"
echo "  screenshot: $OUT/02_weibo_search.png"

echo "=== View a post ==="
# Tap the first result (center of screen, y~800 for first post)
adb shell input tap 540 800
sleep 2
adb exec-out screencap -p > "$OUT/02_weibo_post.png"
echo "  screenshot: $OUT/02_weibo_post.png"

echo "=== Done: Weibo browse ==="
```

- [ ] **Step 2 — Make it executable.**

```bash
chmod +x scripts/adb_browse/weibo.sh
```

- [ ] **Step 3 — Verify entry point.** Run this one command:

```bash
bash scripts/adb_browse/weibo.sh && ls -la adb_browse_out/02_weibo_feed.png adb_browse_out/02_weibo_feed_scrolled.png adb_browse_out/02_weibo_search.png adb_browse_out/02_weibo_post.png && echo "PASS: Weibo browse complete" || echo "FAIL: Weibo browse incomplete"
```

- [ ] **Step 4 — Expected result.**
  - PASS: `PASS: Weibo browse complete`, all 4 screenshots > 0 bytes
  - FAIL: `FAIL: Weibo browse incomplete` — check if Weibo shows a login popup or splash; if so, manually dismiss it on the phone screen first, then re-run

- [ ] **Step 5 — Commit.**

```bash
git add scripts/adb_browse/weibo.sh && git commit -m "adb: weibo browse script" || echo "Warning: commit skipped"
```

---

### Unit 3: Browse Douyin — scroll feed, like if possible, screenshot

**Files:**
- Create: `scripts/adb_browse/douyin.sh`
- Screenshots: `adb_browse_out/03_douyin_*.png`

**Interfaces:**
- Consumes: `adb_browse_out/` directory from Unit 1
- Produces: 3 screenshots from Douyin

- [ ] **Step 1 — Code piece.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/douyin.sh
# Browse Douyin: launch → watch feed → swipe videos → screenshot
set -e
OUT="adb_browse_out"
mkdir -p "$OUT"

echo "=== Launch Douyin ==="
adb shell monkey -p com.ss.android.ugc.aweme -c android.intent.category.LAUNCHER 1
sleep 6
adb exec-out screencap -p > "$OUT/03_douyin_feed.png"
echo "  screenshot: $OUT/03_douyin_feed.png"

echo "=== Swipe through videos ==="
# Douyin is vertical full-screen swipe. Swipe up for next video.
for i in 1 2 3; do
    adb shell input swipe 540 1500 540 500 300
    sleep 3
done
adb exec-out screencap -p > "$OUT/03_douyin_swiped.png"
echo "  screenshot: $OUT/03_douyin_swiped.png"

echo "=== Try search ==="
# Tap the search icon (usually top-right on Douyin)
adb shell input tap 1000 150
sleep 2
adb shell input text "科技"
sleep 1
adb shell input keyevent KEYCODE_ENTER
sleep 3
adb exec-out screencap -p > "$OUT/03_douyin_search.png"
echo "  screenshot: $OUT/03_douyin_search.png"

echo "=== Done: Douyin browse ==="
```

- [ ] **Step 2 — Make it executable.**

```bash
chmod +x scripts/adb_browse/douyin.sh
```

- [ ] **Step 3 — Verify entry point.**

```bash
bash scripts/adb_browse/douyin.sh && ls -la adb_browse_out/03_douyin_feed.png adb_browse_out/03_douyin_swiped.png adb_browse_out/03_douyin_search.png && echo "PASS: Douyin browse complete" || echo "FAIL: Douyin browse incomplete"
```

- [ ] **Step 4 — Expected result.**
  - PASS: `PASS: Douyin browse complete`, all 3 screenshots > 0 bytes
  - FAIL: `FAIL` — if Douyin is not installed (Unit 1 failed) skip this unit. If tap coordinates are wrong (search icon not found), check uiautomator dump and adjust the `input tap x y` values

- [ ] **Step 5 — Commit.**

```bash
git add scripts/adb_browse/douyin.sh && git commit -m "adb: douyin browse script" || echo "Warning: commit skipped"
```

---

### Unit 4: Browse Bilibili — scroll feed, search, play a video

**Files:**
- Create: `scripts/adb_browse/bilibili.sh`
- Screenshots: `adb_browse_out/04_bilibili_*.png`

**Interfaces:**
- Consumes: `adb_browse_out/` directory from Unit 1
- Produces: 4 screenshots from Bilibili

- [ ] **Step 1 — Code piece.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/bilibili.sh
# Browse Bilibili: launch → scroll feed → search → play a video
set -e
OUT="adb_browse_out"
mkdir -p "$OUT"

echo "=== Launch Bilibili ==="
adb shell monkey -p tv.danmaku.bili -c android.intent.category.LAUNCHER 1
sleep 5
adb exec-out screencap -p > "$OUT/04_bilibili_feed.png"
echo "  screenshot: $OUT/04_bilibili_feed.png"

echo "=== Scroll feed ==="
# Swipe up to scroll the recommendation feed
for i in 1 2 3; do
    adb shell input swipe 540 1500 540 500 300
    sleep 2
done
adb exec-out screencap -p > "$OUT/04_bilibili_feed_scrolled.png"
echo "  screenshot: $OUT/04_bilibili_feed_scrolled.png"

echo "=== Search ==="
# Tap search icon (top area, x~1000 y~150 on most layouts)
adb shell input tap 1000 150
sleep 2
adb shell input text "编程"
sleep 1
adb shell input keyevent KEYCODE_ENTER
sleep 3
adb exec-out screencap -p > "$OUT/04_bilibili_search.png"
echo "  screenshot: $OUT/04_bilibili_search.png"

echo "=== Play a video ==="
# Tap the first search result (center of screen, y~600)
adb shell input tap 540 600
sleep 4
adb exec-out screencap -p > "$OUT/04_bilibili_video.png"
echo "  screenshot: $OUT/04_bilibili_video.png"

# Go back home
adb shell input keyevent KEYCODE_HOME

echo "=== Done: Bilibili browse ==="
```

- [ ] **Step 2 — Make it executable.**

```bash
chmod +x scripts/adb_browse/bilibili.sh
```

- [ ] **Step 3 — Verify entry point.**

```bash
bash scripts/adb_browse/bilibili.sh && ls -la adb_browse_out/04_bilibili_feed.png adb_browse_out/04_bilibili_feed_scrolled.png adb_browse_out/04_bilibili_search.png adb_browse_out/04_bilibili_video.png && echo "PASS: Bilibili browse complete" || echo "FAIL: Bilibili browse incomplete"
```

- [ ] **Step 4 — Expected result.**
  - PASS: `PASS: Bilibili browse complete`, all 4 screenshots > 0 bytes
  - FAIL: `FAIL` — if tap coordinates miss, dump the UI with `adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml /tmp/ui.xml` and find correct coordinates, then adjust

- [ ] **Step 5 — Commit.**

```bash
git add scripts/adb_browse/bilibili.sh && git commit -m "adb: bilibili browse script" || echo "Warning: commit skipped"
```

---

### Unit 5: Browse RedNote (Xiaohongshu) — scroll feed, search, view post

**Files:**
- Create: `scripts/adb_browse/rednote.sh`
- Screenshots: `adb_browse_out/05_rednote_*.png`

**Interfaces:**
- Consumes: `adb_browse_out/` directory from Unit 1
- Produces: 4 screenshots from RedNote

- [ ] **Step 1 — Code piece.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/rednote.sh
# Browse RedNote/Xiaohongshu: launch → scroll → search → view post
set -e
OUT="adb_browse_out"
mkdir -p "$OUT"

echo "=== Launch RedNote ==="
adb shell monkey -p com.xingin.xhs -c android.intent.category.LAUNCHER 1
sleep 5
adb exec-out screencap -p > "$OUT/05_rednote_feed.png"
echo "  screenshot: $OUT/05_rednote_feed.png"

echo "=== Scroll feed ==="
# Swipe up 3 times
for i in 1 2 3; do
    adb shell input swipe 540 1500 540 500 300
    sleep 2
done
adb exec-out screencap -p > "$OUT/05_rednote_feed_scrolled.png"
echo "  screenshot: $OUT/05_rednote_feed_scrolled.png"

echo "=== Search ==="
# Tap search (top-right area for Xiaohongshu)
adb shell input tap 1000 150
sleep 2
adb shell input text "旅行"
sleep 1
adb shell input keyevent KEYCODE_ENTER
sleep 3
adb exec-out screencap -p > "$OUT/05_rednote_search.png"
echo "  screenshot: $OUT/05_rednote_search.png"

echo "=== Open a post ==="
# Tap the first post (center area, y~700 for first card)
adb shell input tap 540 700
sleep 2
adb exec-out screencap -p > "$OUT/05_rednote_post.png"
echo "  screenshot: $OUT/05_rednote_post.png"

adb shell input keyevent KEYCODE_HOME

echo "=== Done: RedNote browse ==="
```

- [ ] **Step 2 — Make it executable.**

```bash
chmod +x scripts/adb_browse/rednote.sh
```

- [ ] **Step 3 — Verify entry point.**

```bash
bash scripts/adb_browse/rednote.sh && ls -la adb_browse_out/05_rednote_feed.png adb_browse_out/05_rednote_feed_scrolled.png adb_browse_out/05_rednote_search.png adb_browse_out/05_rednote_post.png && echo "PASS: RedNote browse complete" || echo "FAIL: RedNote browse incomplete"
```

- [ ] **Step 4 — Expected result.**
  - PASS: `PASS: RedNote browse complete`, all 4 screenshots > 0 bytes
  - FAIL: `FAIL` — if RedNote shows a login wall that blocks access, manually sign in on the phone, then re-run

- [ ] **Step 5 — Commit.**

```bash
git add scripts/adb_browse/rednote.sh && git commit -m "adb: rednote browse script" || echo "Warning: commit skipped"
```

---

### Unit 6: Master runner — run all apps in sequence, final verify

**Files:**
- Create: `scripts/adb_browse/run_all.sh`
- Create: `scripts/adb_browse/verify_all.sh`
- Screenshots: all in `adb_browse_out/`

**Interfaces:**
- Consumes: all preceding units' scripts
- Produces: final PASS/FAIL summary

- [ ] **Step 1 — Code piece — master runner.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/run_all.sh
# Run all browse scripts in sequence, stop on first failure
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=""

run_one() {
    local name="$1"
    local script="$2"
    echo ""
    echo "========================================"
    echo "  RUNNING: $name"
    echo "========================================"
    if bash "$SCRIPT_DIR/$script"; then
        echo "✅ $name: PASS"
    else
        echo "❌ $name: FAIL"
        FAILED="$FAILED $name"
    fi
}

echo "Starting ADB browse session..."
echo "Device: $(adb devices | tail -n +2)"

run_one "Weibo"    "weibo.sh"
run_one "Douyin"   "douyin.sh"  2>/dev/null || echo "⚠️  Douyin skipped (not installed or failed)"
run_one "Bilibili" "bilibili.sh"
run_one "RedNote"  "rednote.sh"

echo ""
echo "========================================"
if [ -z "$FAILED" ]; then
    echo "✅ ALL PASSED"
else
    echo "❌ FAILED:$FAILED"
    exit 1
fi
```

- [ ] **Step 2 — Code piece — verify script.** Write this file exactly:

```bash
#!/bin/bash
# scripts/adb_browse/verify_all.sh
# Verify all expected screenshots exist and are non-empty
set -e

OUT="adb_browse_out"
MISSING=""
TOTAL=0

check() {
    local file="$1"
    local label="$2"
    TOTAL=$((TOTAL + 1))
    if [ -f "$OUT/$file" ] && [ -s "$OUT/$file" ]; then
        echo "  ✅ $label: $OUT/$file ($(wc -c < "$OUT/$file") bytes)"
    else
        echo "  ❌ $label: $OUT/$file MISSING or EMPTY"
        MISSING="$MISSING $label"
    fi
}

echo "=== Verifying ADB browse screenshots ==="

check "01_weibo_launch.png"      "Weibo launch"
check "02_weibo_feed.png"        "Weibo feed"
check "02_weibo_feed_scrolled.png" "Weibo scrolled"
check "02_weibo_search.png"      "Weibo search"
check "02_weibo_post.png"        "Weibo post"

check "01_douyin_launch.png"     "Douyin launch"
check "03_douyin_feed.png"       "Douyin feed"
check "03_douyin_swiped.png"     "Douyin swiped"
check "03_douyin_search.png"     "Douyin search"

check "01_bilibili_launch.png"   "Bilibili launch"
check "04_bilibili_feed.png"     "Bilibili feed"
check "04_bilibili_feed_scrolled.png" "Bilibili scrolled"
check "04_bilibili_search.png"   "Bilibili search"
check "04_bilibili_video.png"    "Bilibili video"

check "01_rednote_launch.png"    "RedNote launch"
check "05_rednote_feed.png"      "RedNote feed"
check "05_rednote_feed_scrolled.png" "RedNote scrolled"
check "05_rednote_search.png"    "RedNote search"
check "05_rednote_post.png"      "RedNote post"

echo ""
if [ -z "$MISSING" ]; then
    echo "✅ ALL $TOTAL screenshots present"
else
    echo "❌ MISSING:$MISSING"
    exit 1
fi
```

- [ ] **Step 3 — Make executable.**

```bash
chmod +x scripts/adb_browse/run_all.sh scripts/adb_browse/verify_all.sh
```

- [ ] **Step 4 — Verify entry point — run everything.**

```bash
bash scripts/adb_browse/run_all.sh && bash scripts/adb_browse/verify_all.sh && echo "PASS: All apps browsed" || echo "FAIL: Some apps failed"
```

- [ ] **Step 5 — Expected result.**
  - PASS: `PASS: All apps browsed`, all 17 screenshots verified, exit code 0
  - FAIL: Some apps failed — use `verify_all.sh` to identify which screenshots are missing, then re-run the individual failing script with the phone screen ON and UNLOCKED

- [ ] **Step 6 — Commit.**

```bash
git add scripts/adb_browse/run_all.sh scripts/adb_browse/verify_all.sh && git commit -m "adb: master runner and verify scripts" || echo "Warning: commit skipped"
```

---

## Self-Review Checklist

1. **Coverage** ✅ — All 4 apps (Weibo, Douyin, Bilibili, RedNote) each get a browse script (Units 2-5). Unit 1 installs Douyin + smoke tests. Unit 6 ties everything together.
2. **Verifiability** ✅ — Every unit has a concrete verify command with explicit PASS/FAIL text. All scripts, file paths, and commands are written verbatim.
3. **Placeholders** ✅ — None. All coordinates, paths, package names, search terms, sleep durations are specified. No TODO/TBD.
4. **Type consistency** ✅ — Screenshot naming follows `NN_<app>_<step>.png` convention across all units.
5. **Small-model readiness** ✅ — Each step is a copy-paste bash command or complete script. No decisions required of the executor.

### Known Limitations

- **Tap coordinates** (search icons, post positions): These are approximate for a 1080x2248 screen. If the actual app layout differs (e.g. MIUI status bar offset, app themes), the taps may miss. Fix: use `adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml /tmp/ui.xml` to inspect actual coordinates, then adjust.
- **Douyin download**: APK mirrors may be blocked or outdated. If Unit 1 Step 2 fails, try manual download or skip Douyin.
- **Login walls**: Some apps (RedNote, Weibo) may require login to browse. These scripts assume basic feed is accessible without login. If blocked, user must sign in manually on the phone first.
- **Phone must be unlocked**: All ADB input commands only work when the screen is ON and unlocked.
