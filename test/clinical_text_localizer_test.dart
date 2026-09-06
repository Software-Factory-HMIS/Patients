import 'package:flutter_test/flutter_test.dart';
import 'package:patients/l10n/app_localizations_en.dart';
import 'package:patients/l10n/app_localizations_ur.dart';
import 'package:patients/utils/clinical_text_localizer.dart';

void main() {
  test('localizes structured clinical phrases', () {
    final en = AppLocalizationsEn();
    final ur = AppLocalizationsUr();

    expect(
      ClinicalTextLocalizer.phrase(en, 'Immediately for 2 days'),
      'Immediately for 2 days',
    );
    expect(
      ClinicalTextLocalizer.phrase(ur, 'Immediately for 2 days'),
      'فوری طور پر 2 دن کے لیے',
    );
    expect(ClinicalTextLocalizer.phrase(ur, '2 days'), '2 دن');
    expect(ClinicalTextLocalizer.status(ur, 'CHECKED IN'), 'چیک اِن');
    expect(ClinicalTextLocalizer.status(ur, 'COMPLETED'), 'مکمل');
    expect(
      ClinicalTextLocalizer.checkupTitle(ur, 'Emergency'),
      'Emergency معائنہ',
    );
    expect(
      ClinicalTextLocalizer.phrase(ur, 'Musculoskeletal chest pain'),
      'Musculoskeletal chest pain',
    );
  });
}
