import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/parsers/pdf_parser.dart';

void main() {
  test('parses the real school PDF fixture (黄裕涵 2026-2027-1 课表)', () {
    final bytes =
        File('test/fixtures/huang_yuhan_2026_2027_1_schedule.pdf').readAsBytesSync();
    final courses = PdfParser.parse(bytes, 's1');
    expect(courses, isNotEmpty, reason: 'PDF fixture should yield courses');
    final names = courses.map((c) => c.name).toList();
    expect(names, contains('模拟电子技术*'));
    final sim = courses.firstWhere(
      (c) =>
          c.name == '模拟电子技术*' &&
          c.timeSlots.first.dayOfWeek == 6 &&
          c.timeSlots.first.startPeriod == 1,
      orElse: () => courses.first,
    );
    // 模拟电子技术* 在星期六(day 6) 1-2节 6周 场地:教三楼706 教师:葛健 学分:3.0
    expect(sim.teacher, '葛健');
    expect(sim.venue, '教三楼706');
    expect(sim.credit, 3.0);
  });
}
