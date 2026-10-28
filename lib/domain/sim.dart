/// A call-capable Telecom phone account (usually one per active SIM).
class PhoneAccount {
  const PhoneAccount({required this.id, required this.label, this.slot = 0});
  final String id;
  final String label;
  final int slot;

  factory PhoneAccount.fromMap(Map<Object?, Object?> m) => PhoneAccount(
    id: '${m['id']}',
    label: (m['label'] as String?) ?? 'SIM',
    slot: (m['slot'] as num?)?.toInt() ?? 0,
  );
}

class PhoneAccounts {
  const PhoneAccounts({
    this.accounts = const [],
    this.defaultId,
    this.permitted = false,
  });
  static const none = PhoneAccounts();

  final List<PhoneAccount> accounts;

  /// System / user preferred outgoing account, if one is set.
  final String? defaultId;
  final bool permitted;

  /// The user must pick only when several SIMs exist and no preference is set.
  bool get needsChoice =>
      accounts.length > 1 &&
      (defaultId == null || accounts.every((a) => a.id != defaultId));

  PhoneAccount? byId(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  factory PhoneAccounts.fromMap(Map<Object?, Object?> m) => PhoneAccounts(
    accounts: [
      for (final a in (m['accounts'] as List<Object?>? ?? const []))
        if (a is Map) PhoneAccount.fromMap(a),
    ],
    defaultId: m['defaultId'] as String?,
    permitted: m['permitted'] == true,
  );
}
