import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ya_coursetable/parsers/excel_parser.dart';

void main() {
  test('parses xlsx built in-memory', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('时间段');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('节次');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('星期一');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('星期二');
    sheet.cell(CellIndex.indexByString('C2')).value = IntCellValue(1);
    sheet.cell(CellIndex.indexByString('D2')).value = IntCellValue(1);
    sheet.cell(CellIndex.indexByString('C3')).value =
        TextCellValue('模拟电子技术*\n(1-2节)1-5周,7-12周/校区:南望山校区/场地:教三楼706/教师:葛健/教学班:模拟电子技术-0002/学分:3.0');
    final bytes = excel.encode();
    final courses = ExcelParser.parseBytes(bytes!, 's1');
    expect(courses, hasLength(1));
    expect(courses.single.name, '模拟电子技术*');
    expect(courses.single.teacher, '葛健');
    expect(courses.single.credit, 3.0);
  });
}
