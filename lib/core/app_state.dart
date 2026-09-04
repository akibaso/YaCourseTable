import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier, StateNotifierProvider, StateProvider;

import 'models.dart';
import 'storage.dart';

/// Path of the shared JSON file (document dir) — resolved by the caller
/// (main.dart) via path_provider and kept in this provider.
final appDataPathProvider = StateProvider<String>((ref) => '');

/// The app's root document (多课表 / 多时间表 / 设置)。
final appDataProvider =
    StateNotifierProvider<AppDataNotifier, AsyncValue<AppData>>(
  (ref) => AppDataNotifier(ref),
);

class AppDataNotifier extends StateNotifier<AsyncValue<AppData>> {
  final Ref _ref;
  AppDataNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final path = _ref.read(appDataPathProvider);
    if (path.isEmpty) {
      state = AsyncValue<AppData>.data(AppData());
      return;
    }
    state = AsyncValue.data(await Storage.load(path));
    _saved = path;
  }

  String? _saved;

  Future<void> setPath(String path) async {
    _ref.read(appDataPathProvider.notifier).state = path;
    await _init();
  }

  /// Add a schedule (from import or manual creation) and make it active.
  Future<void> addSchedule(Schedule schedule) async {
    final data = state.value ?? AppData();
    final schedules = [...data.schedules, schedule];
    await _save(AppData(
      activeScheduleId: schedule.id,
      activeWeekPlanId: data.activeWeekPlanId,
      schedules: schedules,
      settings: data.settings,
    ));
  }

  Future<void> updateSchedule(Schedule schedule) async {
    final data = state.value ?? AppData();
    final schedules = [
      for (final s in data.schedules) s.id == schedule.id ? schedule : s,
    ];
    await _save(AppData(
      activeScheduleId: data.activeScheduleId,
      activeWeekPlanId: data.activeWeekPlanId,
      schedules: schedules,
      settings: data.settings,
    ));
  }

  Future<void> setActiveSchedule(String id) async {
    final data = state.value;
    if (data == null) return;
    await _save(AppData(
      activeScheduleId: id,
      activeWeekPlanId: data.activeWeekPlanId,
      schedules: data.schedules,
      settings: data.settings,
    ));
  }

  Future<void> setActiveWeekPlan(String id) async {
    final data = state.value;
    if (data == null) return;
    await _save(AppData(
      activeScheduleId: data.activeScheduleId,
      activeWeekPlanId: id,
      schedules: data.schedules,
      settings: data.settings,
    ));
  }

  Future<void> saveAll(AppData data) => _save(data);

  Future<void> _save(AppData data) async {
    state = AsyncValue.data(data);
    final saved = _saved;
    final path = saved ?? _ref.read(appDataPathProvider);
    if (path != null && path.isNotEmpty) {
      await Storage.save(path, data);
    }
  }
}