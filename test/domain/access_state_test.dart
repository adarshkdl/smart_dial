import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/sim.dart';

void main() {
  group('AccessState', () {
    test('fromMap parses role and permissions, ignores unknown keys', () {
      final s = AccessState.fromMap({
        'isDefaultDialer': false,
        'roleAvailable': true,
        'permissions': {
          'callPhone': 'granted',
          'readContacts': 'denied',
          'bogus': 'granted',
        },
      });
      expect(s.loaded, isTrue);
      expect(s.canPlaceCalls, isTrue);
      expect(s.granted(AppPermission.readContacts), isFalse);
      expect(
        s.status(AppPermission.readCallLog),
        PermissionStatus.denied,
        reason: 'missing → denied',
      );
      expect(s.shouldOfferDefaultRole, isTrue);
    });

    test('role banner hidden when held, unavailable, or not yet loaded', () {
      expect(
        const AccessState(
          loaded: true,
          roleAvailable: true,
          isDefaultDialer: true,
        ).shouldOfferDefaultRole,
        isFalse,
      );
      expect(
        const AccessState(
          loaded: true,
          roleAvailable: false,
        ).shouldOfferDefaultRole,
        isFalse,
      );
      expect(
        const AccessState(roleAvailable: true).shouldOfferDefaultRole,
        isFalse,
      );
    });

    test('feature access decisions', () {
      const s = AccessState(
        permissions: {
          AppPermission.readCallLog: PermissionStatus.granted,
          AppPermission.readContacts: PermissionStatus.permanentlyDenied,
        },
      );
      expect(s.access(AppPermission.readCallLog), FeatureAccess.available);
      expect(s.access(AppPermission.readContacts), FeatureAccess.openSettings);
      expect(s.access(AppPermission.callPhone), FeatureAccess.request);
    });

    test('refresh keeps permanentlyDenied until granted', () {
      const before = AccessState(
        permissions: {
          AppPermission.readContacts: PermissionStatus.permanentlyDenied,
        },
      );
      final stillDenied = before.refreshedWith(
        const AccessState(
          permissions: {AppPermission.readContacts: PermissionStatus.denied},
        ),
      );
      expect(
        stillDenied.status(AppPermission.readContacts),
        PermissionStatus.permanentlyDenied,
      );
      final grantedInSettings = before.refreshedWith(
        const AccessState(
          permissions: {AppPermission.readContacts: PermissionStatus.granted},
        ),
      );
      expect(grantedInSettings.granted(AppPermission.readContacts), isTrue);
    });

    test('role revocation is picked up on refresh', () {
      const held = AccessState(
        loaded: true,
        roleAvailable: true,
        isDefaultDialer: true,
      );
      final revoked = held.refreshedWith(
        const AccessState(roleAvailable: true, isDefaultDialer: false),
      );
      expect(revoked.isDefaultDialer, isFalse);
      expect(revoked.shouldOfferDefaultRole, isTrue);
    });

    test('withResults merges', () {
      const s = AccessState();
      final r = s.withResults({
        AppPermission.callPhone: PermissionStatus.granted,
      });
      expect(r.canPlaceCalls, isTrue);
    });
  });

  group('PhoneAccounts', () {
    const a = PhoneAccount(id: 'a', label: 'Jio', slot: 0);
    const b = PhoneAccount(id: 'b', label: 'Airtel', slot: 1);
    test(
      'single SIM never asks',
      () => expect(const PhoneAccounts(accounts: [a]).needsChoice, isFalse),
    );
    test(
      'dual SIM without default asks',
      () => expect(const PhoneAccounts(accounts: [a, b]).needsChoice, isTrue),
    );
    test('dual SIM with system default respects it', () {
      expect(
        const PhoneAccounts(accounts: [a, b], defaultId: 'b').needsChoice,
        isFalse,
      );
    });
    test(
      'stale default id asks',
      () => expect(
        const PhoneAccounts(accounts: [a, b], defaultId: 'gone').needsChoice,
        isTrue,
      ),
    );
    test('fromMap', () {
      final p = PhoneAccounts.fromMap({
        'accounts': [
          {'id': 'x', 'label': 'SIM 1', 'slot': 0},
        ],
        'defaultId': 'x',
        'permitted': true,
      });
      expect(p.byId('x')!.label, 'SIM 1');
      expect(p.permitted, isTrue);
    });
  });
}
