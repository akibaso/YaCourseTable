import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/core/models.dart';
import 'package:ya_coursetable/parsers/shared_link_parser.dart';

void main() {
  test('share code round-trip', () {
    final data = AppData(
      activeScheduleId: 's1',
      schedules: [
        Schedule(
          id: 's1',
          name: '测试课表',
          semesterStartIso: '2026-09-07',
          courses: [
            Course(
              id: 'c1',
              scheduleId: 's1',
              name: '线性代数B*',
              teacher: '王军霞',
              timeSlots: [
                TimeSlot(dayOfWeek: 3, startPeriod: 7, endPeriod: 8,
                    weekSpec: WeekSpec(weeks: [1, 5, 7, 11]))
              ],
            ),
          ],
        ),
      ],
    );
    final code = SharedLinkParser.encode(data);
    expect(code, isNotEmpty);
    final restored = SharedLinkParser.parse(code);
    expect(restored, isNotNull);
    expect(restored!.schedules.single.courses.single.name, '线性代数B*');
    expect(restored.schedules.single.courses.single.teacher, '王军霞');
  });

  test('invalid share code returns null', () {
    expect(SharedLinkParser.parse('not-a-valid-code'), isNull);
  });
}
