import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/phone_number.dart';

void main() {
  group('normalize', () {
    test('strips formatting, keeps dial characters', () {
      expect(PhoneNumbers.normalize('+91 (98470) 12-345'), '+919847012345');
      expect(PhoneNumbers.normalize('*123#'), '*123#');
      expect(PhoneNumbers.normalize('1800,123;4'), '1800,123;4');
    });
    test('keeps only a leading plus', () {
      expect(PhoneNumbers.normalize('12+34'), '1234');
      expect(PhoneNumbers.normalize('++91'), '+91');
    });
    test(
      'drops letters',
      () => expect(PhoneNumbers.normalize('call 100 now'), '100'),
    );
  });

  group('validate', () {
    test(
      'empty',
      () => expect(PhoneNumbers.validate('  '), NumberValidation.empty),
    );
    test('ok for normal numbers', () {
      expect(PhoneNumbers.validate('98470 12345'), NumberValidation.ok);
      expect(PhoneNumbers.validate('+1 (415) 555-0100'), NumberValidation.ok);
      expect(PhoneNumbers.validate('121'), NumberValidation.ok);
    });
    test(
      'letters are invalid',
      () => expect(
        PhoneNumbers.validate('98ab'),
        NumberValidation.invalidCharacters,
      ),
    );
    test(
      'plus must lead',
      () => expect(
        PhoneNumbers.validate('91+98470'),
        NumberValidation.misplacedPlus,
      ),
    );
    test('too short / too long', () {
      expect(PhoneNumbers.validate('12'), NumberValidation.tooShort);
      expect(
        PhoneNumbers.validate('123456789012345678'),
        NumberValidation.tooLong,
      );
    });
    test('service codes are allowed', () {
      expect(PhoneNumbers.validate('*#06#'), NumberValidation.ok);
      expect(PhoneNumbers.validate('*123#'), NumberValidation.ok);
    });
    test('emergency numbers are never blocked by validation', () {
      for (final n in ['112', '911', '100', '101', '102', '108']) {
        expect(
          PhoneNumbers.validate(n, countryIso: 'IN'),
          NumberValidation.ok,
          reason: n,
        );
      }
      expect(
        PhoneNumbers.validate('999', countryIso: 'GB'),
        NumberValidation.ok,
      );
    });
  });

  group('isEmergency', () {
    test('global and country specific', () {
      expect(PhoneNumbers.isEmergency('112'), isTrue);
      expect(PhoneNumbers.isEmergency('911'), isTrue);
      expect(PhoneNumbers.isEmergency('108', countryIso: 'IN'), isTrue);
      expect(PhoneNumbers.isEmergency('108', countryIso: 'US'), isFalse);
      expect(PhoneNumbers.isEmergency('1120'), isFalse);
      expect(PhoneNumbers.isEmergency('+112'), isFalse);
    });
  });

  group('format', () {
    test('India: progressive 5+5 grouping', () {
      expect(PhoneNumbers.format('98470', countryIso: 'IN'), '98470');
      expect(PhoneNumbers.format('984701', countryIso: 'IN'), '98470 1');
      expect(
        PhoneNumbers.format('9847012345', countryIso: 'IN'),
        '98470 12345',
      );
      expect(PhoneNumbers.format('+919847012345'), '+91 98470 12345');
      expect(
        PhoneNumbers.format('09847012345', countryIso: 'IN'),
        '098470 12345',
      );
    });
    test('NANP', () {
      expect(PhoneNumbers.format('415', countryIso: 'US'), '415');
      expect(PhoneNumbers.format('41555', countryIso: 'US'), '(415) 55');
      expect(
        PhoneNumbers.format('4155550100', countryIso: 'US'),
        '(415) 555-0100',
      );
      expect(PhoneNumbers.format('+14155550100'), '+1 (415) 555-0100');
    });
    test('service codes and unknown countries untouched', () {
      expect(PhoneNumbers.format('*123#', countryIso: 'IN'), '*123#');
      expect(PhoneNumbers.format('+4930123456'), '+4930123456');
      expect(PhoneNumbers.format('', countryIso: 'IN'), '');
    });
    test('over-long input is not mangled', () {
      expect(
        PhoneNumbers.format('123456789012', countryIso: 'IN'),
        '123456789012',
      );
    });
  });

  group('sameNumber', () {
    test('matches with and without country code', () {
      expect(PhoneNumbers.sameNumber('+91 98470 12345', '09847012345'), isTrue);
      expect(PhoneNumbers.sameNumber('9847012345', '+919847012345'), isTrue);
    });
    test(
      'different numbers',
      () =>
          expect(PhoneNumbers.sameNumber('9847012345', '9847012346'), isFalse),
    );
    test('short codes need exact match', () {
      expect(PhoneNumbers.sameNumber('121', '121'), isTrue);
      expect(PhoneNumbers.sameNumber('121', '1121'), isFalse);
    });
    test(
      'empty never matches',
      () => expect(PhoneNumbers.sameNumber('', ''), isFalse),
    );
  });

  test('isPrivate', () {
    expect(PhoneNumbers.isPrivate(''), isTrue);
    expect(PhoneNumbers.isPrivate('-2'), isTrue);
    expect(PhoneNumbers.isPrivate('12345'), isFalse);
  });
}
