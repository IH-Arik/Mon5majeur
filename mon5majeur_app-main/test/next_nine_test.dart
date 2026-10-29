import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/core/utils/datetime_format.dart';

void main() {
  test('next 9:00 Paris', () {
    // Oct 29 2026 (CET after DST end on Oct 25): 9h Paris = 08:00 UTC
    expect(nextParisNineAm(DateTime.utc(2026, 10, 29, 20)), DateTime.utc(2026, 10, 30, 8));
    expect(nextParisNineAm(DateTime.utc(2026, 10, 29, 7)), DateTime.utc(2026, 10, 29, 8));
    // July (CEST): 9h Paris = 07:00 UTC
    expect(nextParisNineAm(DateTime.utc(2026, 7, 10, 12)), DateTime.utc(2026, 7, 11, 7));
  });
}
