# YaCourseTable 设计文档

日期：2026-09-04
状态：已与用户确认关键技术决策（Flutter / 解析范围 / 小部件范围 / 仓库与 CI）

## 1. 目标

构建一个遵循 Material Design 3 的开源课程表应用：

- 无广告、高性能
- 安卓优先，iOS 其次
- 桌面小部件（v1 仅安卓）
- 多课表（多个课表并存、独立配置、快速切换）
- 多时间表（一个课表下多个学期/周计划，日期栏可切换）
- 课表解析（参考 WakeUp 课程表 v6.0.90 的功能实现）

## 2. 已确认决策

| 决策点 | 结论 |
|---|---|
| 技术栈 | Flutter（单代码库覆盖 Android+iOS，内置 Material 3） |
| 课表解析输入 | PDF、Excel（xls/xlsx）、在线 URL（教务系统/分享口令）；HTML/CSV/备份文件同属"从文件导入"；图片 OCR 放 v2 |
| 桌面小部件 | v1 仅安卓（AppWidgetProvider），iOS WidgetKit 放 v2 |
| 仓库与 CI | 现有公开仓库 `akibaso/YaCourseTable` + GitHub Actions；开源化（加 LICENSE + README） |

## 3. 功能清单（参考 WakeUp 功能全集）

### 3.1 主界面（周课表视图）
- 左上角区域：显示当前学期、当前页面周数、外圈指示文字（如"今天在第 1 周"）
- 右上角按钮区：添加课程 / 导入课表 / 导出课表 / 更多功能
- 日期栏区域：周数轴，显示当前周在整个学期的进度位置；点按或滑动可快速跳转到某一周课表；提供"更改当前周"入口
- 左侧时间轴：上午/下午/晚上 + 节次编号
- 课程格子：7 天 × 节次 的网格；同一格子可堆叠多门课程（样例 PDF 中一格多课即此形态）
- 主界面外观设置：背景、主题色、字体大小等

### 3.2 多课表
- 支持创建任意数量课表；每个课表有独立配置（外观、学期信息、课程集合）
- 课表切换器：主界面底部滑轨，展示每个课表缩略图预览，点击即切换
- 课表管理：新建 / 重命名 / 删除 / 复制课表

### 3.3 多时间表（多周计划）
- 每个课表下可建多个"周计划"（WeekPlan）：如第 1-4 周、第 5-8 周（单周）、单双周交替等
- 日期栏周数轴与周计划联动；某周没有课程时显示空状态提示

### 3.4 添加/编辑课程
- 课程基础信息：课程名、教师、场地/校区、教学班、备注
- 课程时间段信息：星期几 + 节次（可多个时间段）、周范围（第 X-Y 周、单双周）
- 校验：至少一个时间段；课程名必填

### 3.5 导入课表
- 从教务系统（在线 URL）：选择教务类型（新 URP / URP / 正方 / 强智 / 旧强智 / 树维 / 重庆大学 / 研究生教务 / 申请适配），抓取并解析页面数据
- 从文件：
  - Excel 模板 / xls / xlsx（openpyxl 式解析）
  - PDF（如 `黄裕涵(2026-2027-1)课表.pdf` 这类教务导出格式：表头"时间段/节次/周一…周日"，单元格内多课堆叠，带周次、校区、场地、教师、教学班、学分）
  - HTML 文件
  - CSV 文件
  - App 导出的备份文件（从分享文件导入）
- 从分享口令：粘贴在线分享课表链接/口令
- 导入后提示"新建课表再导入"与"导入后自行检查课程信息是否正确"

### 3.6 导出课表
- 导出文件：备份文件（JSON）、ICS 日历文件
- 分享：生成在线分享口令/链接（v1 可先做本地口令编码，服务端可后补）
- 桌面小部件（见 3.7）

### 3.7 桌面小部件（v1 仅安卓）
参考 WakeUp 的 4 类小部件 + 配置页：
1. 周课表小部件（schedule_app_widget）：显示某一周的 7 天课表
2. 今日课程列表小部件（today_list_app_widget，含 MIUI 适配变体）
3. 今日 + 明日小部件（today_and_next_day_app_widget）
4. 当前课程小部件（today_course_app_widget）：显示当前正在上的课
- 小部件配置页：选择课表、周计划、外观
- 实现：Flutter 平台通道 + 原生 AppWidgetProvider + RemoteViews；数据与主程序共享本地 JSON 存储

### 3.8 其他功能
- 课程提醒通知（开课前 N 分钟提醒，SCHEDULE_EXACT_ALARM / POST_NOTIFICATIONS）
- 全局设置：主题模式、字体、提醒、语言
- 高级功能：数据备份/恢复、数据管理（清空/导出）

## 4. 架构

```
ya_coursetable/
├── lib/
│   ├── main.dart
│   ├── core/            # 纯 Dart 领域层
│   │   ├── models/      # Schedule, Course, TimeSlot, WeekPlan, Settings
│   │   ├── storage/     # JSON 文件存储（app 文档目录）
│   │   └── weeks.dart   # 中国校历周计算（学期、单双周、周范围）
│   ├── parsers/
│   │   ├── pdf_parser.dart
│   │   ├── excel_parser.dart
│   │   ├── csv_parser.dart
│   │   ├── html_parser.dart
│   │   ├── eas_parser.dart   # 各教务系统类型
│   │   └── shared_link_parser.dart
│   ├── ui/
│   │   ├── screens/     # main, add_course, import, export, settings, widget_config
│   │   ├── widgets/     # timetable_grid, week_axis, schedule_switcher
│   │   └── theme/       # MD3 主题（ColorScheme.fromSeed, dynamic colors 留 v2）
│   └── appwidget/       # 平台通道 + 小部件数据桥
├── android/             # 原生壳 + AppWidgetProvider 实现
├── ios/                 # 原生壳（v1 仅构建，功能同安卓）
├── test/                # 单元 + 小部件桥测试
├── .github/workflows/ci.yml
├── LICENSE               # MIT（开源化）
└── README.md
```

数据流：解析器 → 规范化 Course 列表 → 本地 JSON 存储 → UI 与安卓小部件共读。

### 4.1 性能策略（"高性能"）
- 课表网格用自定义绘制（CustomPainter / SliverGrid），避免 7×N 个独立 Widget 的开销
- 状态管理用 Riverpod（轻量），避免全局重建
- 冷启动：预加载首屏数据，解析器惰性加载
- 无广告：不接任何第三方广告 SDK

## 5. 测试与 CI（"自行测试"）

- 单元测试（Dart）：
  - 各解析器（用 `黄裕涵(2026-2027-1)课表.pdf` 等真实样例做 golden 测试）
  - 周计算、单双周、周范围解析
  - 模型序列化往返、多课表/多周计划数据
- Widget 测试：主界面渲染、添加课程表单校验
- CI（`.github/workflows/ci.yml`）：
  - push/PR → `flutter pub get` + `flutter analyze` + `flutter test`
  - push 到 main → `flutter build apk` 并上传 artifact（安卓优先）
  - 打 tag → 构建 release APK + iOS 归档（macos runner，iOS 其次）
- 本地自测：安装 Flutter SDK（/opt/flutter），`flutter test` + `flutter build apk` 验证

## 6. v2 范围（本期不做）
- 图片 OCR 导入
- iOS WidgetKit 小部件
- 动态取色（Material You）
- 服务端分享链接存储（v1 用本地口令编码）
