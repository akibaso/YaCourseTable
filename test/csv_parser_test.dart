import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/parsers/csv_parser.dart';

void main() {
  test('parses CSV grid text', () {
    // 每个课程单元格本身用引号包裹、其中含换行；后续行必须也用引号，
    // 且首个字段为时段标签（上午/下午…）才会被 CSV 解析器正确换行。
    final csv = '''
时间段,节次,星期一,星期二,星期三,星期四,星期五,星期六,星期日
"上午","1-2","模拟电子技术*
(1-2节)1-5周,7-12周/校区:南望山校区/场地:教三楼706/教师:葛健/教学班:模拟电子技术-0002/学分:3.0",,,
"下午","3-4",,"数字电子技术*
(3-4节)9-16周/教师:熊永华",,
"晚上","7-8",,,"概率论与数理统计A*
(7-8节)1-5周,7-15周/教师:廖勇凯",
''';
    final courses = CsvParser.parseText(csv, 's1');
    final names = courses.map((c) => c.name).toList();
    expect(names, containsAll(['模拟电子技术*', '数字电子技术*', '概率论与数理统计A*']));
    final sim = courses.firstWhere((c) => c.name == '模拟电子技术*');
    expect(sim.teacher, '葛健');
    expect(sim.credit, 3.0);
  });
}
