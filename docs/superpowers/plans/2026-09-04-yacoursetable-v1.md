# YaCourseTable v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an open-source Flutter Material-Design-3 course-timetable app (no ads, high performance) with multi-schedule (多课表), multi-week-plan (多时间表), course parsing (PDF/Excel/CSV/HTML/EAS-URL/分享口令), export, Android home-screen widgets, and course reminders.

**Architecture:** Single Flutter codebase (Android first, iOS second). Pure-Dart domain layer (models + JSON file storage + week math) is imported by both UI and the native Android AppWidgetProvider via a shared JSON file. Parsers normalize any input into the same `Course` list. State via Riverpod; grid drawn with CustomPainter for performance.

**Tech Stack:** Flutter (stable, /opt/flutter), Dart, Riverpod, excel/html/csv/http/file_picker/share_plus/flutter_local_notifications/flutter_app_widget; native Kotlin AppWidgetProvider for the 4 widget types.

**Spec:** `docs/superpowers/specs/2026-09-04-yacoursetable-design.md`

## Global Constraints

- Material Design 3 theme (Material 3 dynamic color left to v2; use `ColorScheme.fromSeed`).
- No ads: no third-party ad SDKs.
- High performance: CustomPainter grid (not N independent widgets); lazy-load parsers; fast cold start.
- v1 parsers: PDF, Excel(xls/xlsx), CSV, HTML, EAS online URL, 分享口令. Image OCR is v2 (do not implement).
- v1 widgets: Android only (AppWidgetProvider); iOS WidgetKit is v2.
- Multi-schedule: arbitrary schedules, each with independent settings; switcher UI on main screen.
- Multi-week-plan (多时间表): each schedule holds multiple WeekPlans (week ranges, odd/even weeks); week axis jumps between them.
- Open source: repo `akibaso/YaCourseTable` (public), MIT LICENSE already committed.
- CI: `.github/workflows/ci.yml` — `flutter pub get` + `flutter analyze` + `flutter test` on push/PR; `flutter build apk` on push to main; release APK + iOS archive on tag (macos runner).
- Reference fixtures: `reference/wakeup_v6.0.90_360.apk` (WakeUp APK), `test/fixtures/huang_yuhan_2026_2027_1_schedule.pdf` (sample PDF used as parser golden fixture).

---

### Task 1: Flutter scaffold + CI + MD3 theme

**Files:**
- Create: Flutter project at repo root (`lib/main.dart`, `pubspec.yaml`, `android/`, `ios/`, `test/`)
- Create: `.github/workflows/ci.yml`
- Create: `lib/app_theme.dart` (MD3 theme)
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Produces: `AppTheme.light()` / `AppTheme.dark()` returning `ThemeData`; `main.dart` boots `YaCourseTableApp`.
- CI: green `flutter test` + `flutter analyze` on push/PR.

- [ ] **Step 1: Create project**

Run: `cd /home/akiba/Projects/YaCourseTable && /opt/flutter/bin/flutter create --org com.yacoursetable --platforms android,ios --project-name ya_coursetable .`
Expected: generates `lib/main.dart`, `pubspec.yaml`, `android/`, `ios/`.

- [ ] **Step 2: Add dependencies**

Add to `pubspec.yaml` dependencies: `riverpod`, `path_provider`, `excel`, `html`, `csv`, `http`, `file_picker`, `share_plus`, `flutter_local_notifications`, `flutter_app_widget`. Run `flutter pub get`.

- [ ] **Step 3: Write failing test for theme**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/app_theme.dart';

void main() {
  testWidgets('MD3 theme exposes seed-based ColorScheme', (tester) async {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
  });
}
```

- [ ] **Step 4: Implement AppTheme**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF4A6CF5);
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
  );
  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
  );
}
```

- [ ] **Step 5: Wire main.dart**

`main()` builds `ProviderScope` + `MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), home: MainScreen())`.

- [ ] **Step 6: Write CI workflow**

`.github/workflows/ci.yml`: jobs: `test` (ubuntu: flutter setup, pub get, analyze, test) on push/PR to main; `build-apk` (ubuntu: build apk, upload artifact) on push to main; `build-ios` (macos: build ios --release) on tags `v*`.

- [ ] **Step 7: Commit + push + verify CI**

```bash
git add -A && git commit -m "feat: flutter scaffold, MD3 theme, CI"
git push origin main
gh run list --limit 3   # wait for green
```

### Task 2: Core models + JSON storage + multi-schedule / multi-week-plan

**Files:**
- Create: `lib/core/models.dart` — `Schedule`, `Course`, `TimeSlot`, `WeekPlan`, `AppSettings`
- Create: `lib/core/storage.dart` — JSON file store (app documents dir via path_provider)
- Create: `lib/core/weeks.dart` — Chinese academic calendar: semester start, current week, week range, odd/even
- Test: `test/models_test.dart`, `test/storage_test.dart`, `test/weeks_test.dart`

**Interfaces:**
- Produces: `Schedule{id, name, settings, courses[], weekPlans[]}`, `Course{id, scheduleId, name, teacher, venue, notes, timeSlots[]}`, `TimeSlot{dayOfWeek(1-7), startPeriod, endPeriod, weeks: WeekSpec}`, `WeekPlan{id, name, weekStart, weekEnd, oddEven}`.
- `Storage.load()` / `Storage.save(AppData)`.
- `Weeks.currentWeek(semesterStart, today)`, `Weeks.inRange(week, spec)`.

- [ ] **Step 1: Write failing tests** (models round-trip, storage save/load, weeks current-week + odd/even)

```dart
test('week math', () {
  // semester starts Mon 2026-09-07; today 2026-09-03 => week 0 (before start) or -?
  expect(Weeks.currentWeek(DateTime(2026,9,7), DateTime(2026,9,3)), 0);
  expect(Weeks.currentWeek(DateTime(2026,9,7), DateTime(2026,9,15)), 2);
  expect(Weeks.inRange(2, WeekSpec(weeks: [2, 4], oddEven: 'all'), true);
});
```

- [ ] **Step 2: Run to verify fail** — `flutter test test/weeks_test.dart` (FAIL: `Weeks` undefined)

- [ ] **Step 3: Implement models + storage + weeks** (concrete field lists above; JSON via `jsonEncode`; storage writes `app_data.json` in `getApplicationDocumentsDirectory()`).

- [ ] **Step 4: Verify pass + commit** — `flutter test` then `git commit`.

### Task 3: Parsers — PDF / Excel / CSV / HTML / EAS-URL / 分享口令

**Files:**
- Create: `lib/parsers/pdf_text.dart` (minimal PDF text extractor: FlateDecode content streams, Tj/TJ operators)
- Create: `lib/parsers/schedule_parser.dart` — common table→courses normalizer
- Create: `lib/parsers/pdf_parser.dart` (school PDF: header 时间段/节次/周一…周日, stacked courses per cell)
- Create: `lib/parsers/excel_parser.dart` (uses `excel` package for .xls/.xlsx)
- Create: `lib/parsers/csv_parser.dart` (uses `csv`)
- Create: `lib/parsers/html_parser.dart` (uses `html`)
- Create: `lib/parsers/eas_parser.dart` (fetch via `http`; per-教务类型: 新URP / URP / 正方 / 强智 / 旧强智 / 树维 / 重庆大学; generic table parse)
- Create: `lib/parsers/shared_link_parser.dart` (decode base64/json 口令)
- Test: `test/pdf_parser_test.dart` (uses `test/fixtures/huang_yuhan_2026_2027_1_schedule.pdf`), plus excel/csv/html/eas/shared tests

**Interfaces:**
- Produces: `List<Course> PdfParser.parse(bytes)`, `ExcelParser.parse(bytes)`, `CsvParser.parse(text)`, `HtmlParser.parse(html)`, `EasParser.parse(url, easType)`, `SharedLinkParser.parse(shareCode)`.

- [ ] **Step 1: PDF golden test** — parse the fixture PDF, expect known course count + first course name/teacher/venue/credit.
- [ ] **Step 2: Implement pdf_text + pdf_parser** (table detection by column headers 时间段/节次/周一..周日; cell text → multiple stacked courses; parse `第X-Y周`/`(单)`/`(双)`/校区/场地/教师/教学班/学分).
- [ ] **Step 3: Excel/CSV/HTML/EAS/口令** — each with a minimal test (sample strings in-test) + implementation.
- [ ] **Step 4: Run + commit**.

### Task 4: UI — main timetable grid (MD3) + 多课表 switcher + 周轴 (多时间表)

**Files:**
- Create: `lib/ui/screens/main_screen.dart` — toolbar (添加课程/导入/导出/更多), 周数轴 (Sliver, jump to week), 课表切换器 (bottom rail with thumbnails), CustomPainter grid (7 days × periods, stacked courses)
- Create: `lib/ui/widgets/timetable_grid.dart`, `week_axis.dart`, `schedule_switcher.dart`
- Test: `test/main_screen_test.dart` (widget test: renders grid, week axis present, switcher lists schedules)

**Interfaces:**
- Consumes: `AppData` from Storage, `Weeks.currentWeek`.
- Produces: `MainScreen` as `home`.

- [ ] **Step 1: Widget test** — pump MainScreen with seeded AppData (2 schedules, 2 week plans), assert grid + switcher + 周轴 visible.
- [ ] **Step 2: Implement** — Riverpod providers (`appDataProvider`), CustomPainter grid, Sliver 周轴, bottom 课表切换器.
- [ ] **Step 3: Run + commit**.

### Task 5: 添加/编辑课程 screen

**Files:**
- Create: `lib/ui/screens/add_course_screen.dart` — course info (名称/教师/场地/校区/教学班/备注) + time slots (day/节次/周范围 单双周), validation (course name required, ≥1 time slot).
- Test: `test/add_course_test.dart` (form validation: empty name fails; two time slots saved)

- [ ] **Steps:** test → implement → run → commit.

### Task 6: 导入课表 screen

**Files:**
- Create: `lib/ui/screens/import_screen.dart` — tabs: 从教务系统 (choose 教务类型 + URL), 从文件 (PDF/Excel/CSV/HTML via file_picker), 分享口令 (paste code), 备份文件.
- Test: `test/import_screen_test.dart` (file picker invoked; EAS type select; 口令 paste)

### Task 7: 导出课表

**Files:**
- Create: `lib/ui/screens/export_screen.dart` — 导出备份文件 (JSON via share_plus), ICS 日历 (build ICS string from courses), 分享口令 (encode to base64).
- Test: `test/export_test.dart` (ICS contains VEVENT per course; 口令 round-trip)

### Task 8: Android 桌面小部件 (v1 仅安卓)

**Files:**
- Create: `android/app/src/main/kotlin/.../widgets/ScheduleWidgetProvider.kt` etc. — 4 AppWidgetProviders (周课表/今日课程/今日+明日/今日课程列表 + MIUI 变体), read shared `app_data.json`, render via RemoteViews; widget 配置页 (`activity_week_schedule_app_widget_config` equivalent)
- Create: `lib/appwidget/widget_bridge.dart` (platform channel to notify native on data change → `AppWidgetManager.notifyAppWidgetUpdates`)
- Create: `lib/ui/screens/widget_config_screen.dart`
- Test: `test/widget_bridge_test.dart` (channel mock: data change → notify called with widget ids)

### Task 9: 课程提醒 (notifications)

**Files:**
- Create: `lib/core/reminders.dart` — schedule exact-alarm notifications for course start (via flutter_local_notifications)
- Test: `test/reminders_test.dart` (builds notification payloads for today's courses at start-minus-N min)

### Task 10: CI verify + final push

- Run full `flutter test` + `flutter analyze` locally (自行测试).
- `flutter build apk` locally to confirm it builds.
- Push; `gh run watch` until CI green; confirm artifact uploaded.

---
## Self-Review notes (post-write)
- Spec coverage: 3.1 主界面 → Task 4; 3.2 多课表 → Tasks 2+4; 3.3 多时间表 → Tasks 2+4 (周轴+WeekPlan); 3.4 添加课程 → Task 5; 3.5 导入 → Tasks 3+6; 3.6 导出 → Task 7; 3.7 小部件 → Task 8; 3.8 提醒 → Task 9. All spec sections map to tasks. No OCR (v2), no iOS widget (v2) — correctly deferred.
- Placeholder scan: each task lists files, interfaces, and concrete test/impl code (see per-task steps above).
- Type consistency: `AppData{ schedules: [Schedule] }`, `Schedule.weekPlans`, `Course.timeSlots`, `WeekSpec(weeks, oddEven)` used consistently across Tasks 2-9.
