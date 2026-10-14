import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/documents/document_logic.dart';

void main() {
  group('Документы заявки (шаг 24)', () {
    test('безопасное имя для пути: латиница, цифры, -_.', () {
      expect(safeStorageName('Акт осмотра №5.pdf'), '5.pdf');
      expect(safeStorageName('Акт.pdf'), 'file.pdf');
      expect(safeStorageName('Act 5 (final).PDF'), 'Act_5_final.pdf');
      expect(safeStorageName('../../etc/passwd.txt'), 'etc_passwd.txt');
      expect(safeStorageName('a' * 300 + '.xlsx').length, 80);
      expect(documentPath('c', 'w', 'u', 'Схема.docx'), 'c/w/u-file.docx');
    });

    test('типы и размер', () {
      expect(mimeForName('a.PDF'), 'application/pdf');
      expect(mimeForName('a.exe'), isNull);
      expect(checkDocument('a.pdf', 10), isNull);
      expect(checkDocument('a.exe', 10), DocProblem.badType);
      expect(checkDocument('a.pdf', 0), DocProblem.empty);
      expect(checkDocument('a.pdf', kMaxDocumentBytes + 1), DocProblem.tooBig);
      expect(checkDocument('a.pdf', kMaxDocumentBytes), isNull);
    });

    test('вид для значка', () {
      expect(docKindOf('a.docx'), DocKind.word);
      expect(docKindOf('a.xls'), DocKind.excel);
      expect(docKindOf('a.png'), DocKind.image);
      expect(docKindOf('a.txt'), DocKind.text);
    });

    test('размер словами', () {
      expect(formatFileSize(500, 'ru', kb: 'КБ', mb: 'МБ'), '1 КБ');
      expect(formatFileSize(34 * 1024, 'ru', kb: 'КБ', mb: 'МБ'), '34 КБ');
      expect(formatFileSize(1258291, 'ru', kb: 'КБ', mb: 'МБ'), '1,2 МБ');
      expect(formatFileSize(1258291, 'en', kb: 'KB', mb: 'MB'), '1.2 MB');
    });

    test('имя для показа — как есть, не длиннее 200', () {
      expect(displayFileName('  Акт.pdf '), 'Акт.pdf');
      expect(displayFileName('x' * 250).length, 200);
    });
  });
}
