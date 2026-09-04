import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/parsers/eas_parser.dart';
import 'package:ya_coursetable/parsers/html_parser.dart';

void main() {
  test('EAS type list matches WakeUp doc', () {
    expect(EasParser.easTypes, containsAll([
      '新URP系统', 'URP系统', '正方教务', '强智教务',
      '旧强智教务', '树维教务', '重庆大学', '研究生教务', '申请适配',
    ]));
  });

  test('HTML table parsing via EAS page content', () {
    final html = '''
    <html><body>
    <table>
      <tr><td>时间段</td><td>节次</td><td>星期一</td><td>星期二</td></tr>
      <tr><td>上午</td><td>1</td><td>计算机程序设计基础*&#10;(1-2节)6-15周/校区:南望山校区/场地:东教楼A0208/教师:周洋/学分:2.5</td><td></td></tr>
    </table>
    </body></html>
    ''';
    final courses = HtmlParser.parseHtml(html, 's1');
    expect(courses, hasLength(1));
    expect(courses.single.name, '计算机程序设计基础*');
    expect(courses.single.teacher, '周洋');
    expect(courses.single.credit, 2.5);
  });
}
