/// Default-Phone-role and runtime-permission state, plus the decisions derived from it.
library;

enum AppPermission {
  callPhone,
  readCallLog,
  writeCallLog,
  readContacts,
  writeContacts,
  readPhoneState,
  postNotifications;

  /// Key used on the method channel.
  String get key => name;

  static AppPermission? fromKey(String k) {
    for (final p in values) {
      if (p.key == k) return p;
    }
    return null;
  }
}

enum PermissionStatus {
  granted,
  denied,

  /// Denied with "don't ask again" — only Settings can grant it.
  permanentlyDenied;

  static PermissionStatus fromKey(Object? k) => switch (k) {
    'granted' => PermissionStatus.granted,
    'permanentlyDenied' => PermissionStatus.permanentlyDenied,
    _ => PermissionStatus.denied,
  };
}

/// What a screen should do about a feature's permission.
enum FeatureAccess { available, request, openSettings }

class AccessState {
  const AccessState({
    this.isDefaultDialer = false,
    this.roleAvailable = false,
    this.permissions = const {},
    this.loaded = false,
  });

  static const unknown = AccessState();

  final bool isDefaultDialer;
  final bool roleAvailable;
  final Map<AppPermission, PermissionStatus> permissions;
  final bool loaded;

  PermissionStatus status(AppPermission p) =>
      permissions[p] ?? PermissionStatus.denied;
  bool granted(AppPermission p) => status(p) == PermissionStatus.granted;

  FeatureAccess access(AppPermission p) => switch (status(p)) {
    PermissionStatus.granted => FeatureAccess.available,
    PermissionStatus.denied => FeatureAccess.request,
    PermissionStatus.permanentlyDenied => FeatureAccess.openSettings,
  };

  bool get canPlaceCalls => granted(AppPermission.callPhone);
  bool get canReadSims => granted(AppPermission.readPhoneState);

  /// Show the "set as default" banner: role exists on this device and isn't held.
  bool get shouldOfferDefaultRole =>
      loaded && roleAvailable && !isDefaultDialer;

  /// Merges fresh platform state but keeps a known `permanentlyDenied`, which the
  /// platform can only report right after a request.
  AccessState refreshedWith(AccessState fresh) {
    final merged = <AppPermission, PermissionStatus>{...fresh.permissions};
    permissions.forEach((p, s) {
      if (s == PermissionStatus.permanentlyDenied &&
          merged[p] != PermissionStatus.granted) {
        merged[p] = PermissionStatus.permanentlyDenied;
      }
    });
    return AccessState(
      isDefaultDialer: fresh.isDefaultDialer,
      roleAvailable: fresh.roleAvailable,
      permissions: merged,
      loaded: true,
    );
  }

  AccessState withResults(Map<AppPermission, PermissionStatus> results) =>
      AccessState(
        isDefaultDialer: isDefaultDialer,
        roleAvailable: roleAvailable,
        permissions: {...permissions, ...results},
        loaded: loaded,
      );

  AccessState withDefaultDialer(bool held) => AccessState(
    isDefaultDialer: held,
    roleAvailable: roleAvailable,
    permissions: permissions,
    loaded: loaded,
  );

  factory AccessState.fromMap(Map<Object?, Object?> m) {
    final raw = (m['permissions'] as Map?) ?? const {};
    final perms = <AppPermission, PermissionStatus>{};
    raw.forEach((k, v) {
      final p = AppPermission.fromKey('$k');
      if (p != null) perms[p] = PermissionStatus.fromKey(v);
    });
    return AccessState(
      isDefaultDialer: m['isDefaultDialer'] == true,
      roleAvailable: m['roleAvailable'] == true,
      permissions: perms,
      loaded: true,
    );
  }
}
