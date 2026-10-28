// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Dial';

  @override
  String get tabKeypad => 'Keypad';

  @override
  String get tabRecents => 'Recents';

  @override
  String get tabContacts => 'Contacts';

  @override
  String get defaultRoleTitle => 'Make Smart Dial your phone app';

  @override
  String get defaultRoleBody =>
      'Needed to answer calls and show the in-call screen. Until then, calls use your current phone app.';

  @override
  String get defaultRoleAction => 'Set as default';

  @override
  String get notNow => 'Not now';

  @override
  String get call => 'Call';

  @override
  String get backspace => 'Delete digit';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get numberCopied => 'Number copied';

  @override
  String get enterNumber => 'Enter a number';

  @override
  String get errorInvalidNumber => 'That doesn\'t look like a valid number';

  @override
  String get errorCallPermission => 'Phone permission is needed to place calls';

  @override
  String get errorCallFailed => 'Couldn\'t place the call';

  @override
  String get chooseSim => 'Call with';

  @override
  String get recentsPermissionTitle => 'See your call history';

  @override
  String get recentsPermissionBody =>
      'Smart Dial reads the call log on this phone to show recent calls. It never leaves your device.';

  @override
  String get contactsPermissionTitle => 'See your contacts';

  @override
  String get contactsPermissionBody =>
      'Smart Dial reads contacts on this phone to show names and search. They never leave your device.';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get openSettings => 'Open settings';

  @override
  String get permissionSettingsHint =>
      'Access was turned off. You can enable it in Settings.';

  @override
  String get noRecents => 'No recent calls';

  @override
  String get noContacts => 'No contacts on this phone';

  @override
  String get noResults => 'No matches';

  @override
  String get errorLoading => 'Couldn\'t load this list';

  @override
  String get retry => 'Retry';

  @override
  String get searchRecents => 'Search recents';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get filterAll => 'All';

  @override
  String get filterMissed => 'Missed';

  @override
  String get unknownNumber => 'Unknown';

  @override
  String get privateNumber => 'Private number';

  @override
  String get callTypeIncoming => 'Incoming';

  @override
  String get callTypeOutgoing => 'Outgoing';

  @override
  String get callTypeMissed => 'Missed';

  @override
  String get callTypeRejected => 'Declined';

  @override
  String get callTypeBlocked => 'Blocked';

  @override
  String get callTypeVoicemail => 'Voicemail';

  @override
  String get deleteEntry => 'Delete from history';

  @override
  String get deleted => 'Deleted';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get statusDialing => 'Calling…';

  @override
  String get statusIncoming => 'Incoming call';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusOnHold => 'On hold';

  @override
  String get statusEnded => 'Call ended';

  @override
  String get answer => 'Answer';

  @override
  String get decline => 'Decline';

  @override
  String get endCall => 'End call';

  @override
  String get mute => 'Mute';

  @override
  String get speaker => 'Speaker';

  @override
  String get keypad => 'Keypad';

  @override
  String get hold => 'Hold';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get hideKeypad => 'Hide keypad';

  @override
  String get swap => 'Swap';

  @override
  String onHoldWith(String name) {
    return 'On hold: $name';
  }

  @override
  String incomingWaiting(String name) {
    return 'Incoming: $name';
  }

  @override
  String callNumberLabel(String number) {
    return 'Call $number';
  }

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get rememberSim => 'Remember for this number';

  @override
  String get removeFavorite => 'Remove favorite';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get errorFavoritePermission =>
      'Contacts access is needed to change favorites';

  @override
  String get openInContacts => 'Open in Contacts';

  @override
  String get message => 'Message';

  @override
  String get addToHomeScreen => 'Add to home screen';

  @override
  String get errorShortcut => 'Your launcher doesn\'t support shortcuts';

  @override
  String speedDialNotSetTitle(int key) {
    return 'Speed dial $key isn\'t set';
  }

  @override
  String get speedDialNotSetBody =>
      'Assign a contact to call them by long-pressing this key.';

  @override
  String get assign => 'Assign';

  @override
  String get addContact => 'Add to contacts';

  @override
  String get showContactSuggestions => 'Show contact suggestions';

  @override
  String speedDialAssignTitle(int key) {
    return 'Speed dial $key';
  }

  @override
  String speedDialSaved(int key, String name) {
    return 'Speed dial $key: $name';
  }

  @override
  String get details => 'Details';

  @override
  String get frequent => 'Frequent';

  @override
  String get noFavorites => 'Star contacts to see them here';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColor => 'Accent colour';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentDynamic => 'Wallpaper';

  @override
  String get keypadSize => 'Keypad size';

  @override
  String get sizeCompact => 'Compact';

  @override
  String get sizeNormal => 'Normal';

  @override
  String get sizeLarge => 'Large';

  @override
  String get t9Suggestions => 'Smart search on keypad';

  @override
  String get t9SuggestionsHint =>
      'Match contacts by keypad letters and numbers as you type';

  @override
  String get keypadTones => 'Dial pad tones';

  @override
  String get keypadTonesHint =>
      'Also follows the system setting and silent mode';

  @override
  String get keypadHaptics => 'Vibrate on keypress';

  @override
  String get speedDial => 'Speed dial';

  @override
  String get voicemail => 'Voicemail';

  @override
  String get notSet => 'Not set';

  @override
  String get remove => 'Remove';

  @override
  String get callsAndSim => 'Calls & SIM';

  @override
  String get rememberSimSetting => 'Remember SIM per contact';

  @override
  String rememberSimHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numbers remembered',
      one: '1 number remembered',
      zero: 'No numbers remembered',
    );
    return '$_temp0';
  }

  @override
  String get clearSimChoices => 'Forget remembered SIM choices';

  @override
  String get favoriteShortcuts => 'Favorites in app shortcuts';

  @override
  String get favoriteShortcutsHint =>
      'Long-press the app icon to call up to 4 favorites';

  @override
  String get isDefaultApp => 'Smart Dial is your phone app';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySummary =>
      'Contacts and call history stay on this phone. Smart Dial only stores its own settings, notes, reminders and diagnostics — encrypted on this device, never backed up or uploaded.';

  @override
  String get clearAppData => 'Clear Smart Dial data';

  @override
  String get clearAppDataHint =>
      'Settings, speed dial, SIM choices, notes, reminders and diagnostics. Your contacts and call history are not affected.';

  @override
  String get clearAppDataConfirm =>
      'Delete all Smart Dial settings, speed dial entries, SIM choices, notes, reminders and diagnostics?';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get appDataCleared => 'Smart Dial data cleared';

  @override
  String get filterDeclined => 'Declined';

  @override
  String get allSims => 'All SIMs';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get remindIn15 => 'In 15 minutes';

  @override
  String get remindIn1h => 'In 1 hour';

  @override
  String get remindThisEvening => 'This evening';

  @override
  String get remindTomorrowMorning => 'Tomorrow morning';

  @override
  String get remindMe => 'Remind me to call';

  @override
  String get pickDateTime => 'Pick date & time';

  @override
  String reminderSetFor(String time) {
    return 'Reminder set: $time';
  }

  @override
  String get reminderNoNotifications =>
      'Reminder saved, but notifications are off for Smart Dial';

  @override
  String get reminders => 'Reminders';

  @override
  String get exactAlarmHint =>
      'Reminders may arrive up to 10 minutes late. Allow exact alarms for on-time reminders.';

  @override
  String get allowExactAlarms => 'Allow';

  @override
  String get noReminders => 'No reminders';

  @override
  String get overdue => 'Overdue';

  @override
  String get reminderDone => 'Done';

  @override
  String get delete => 'Delete';

  @override
  String get addNote => 'Add note';

  @override
  String get editNote => 'Edit note';

  @override
  String get noteHint => 'Write a note — only stored on this phone';

  @override
  String get save => 'Save';

  @override
  String get notes => 'Notes';

  @override
  String get noNotes => 'No notes yet';

  @override
  String get remindToCallBack => 'Remind me to call back';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get copyReport => 'Copy report';

  @override
  String get reportCopied => 'Report copied';

  @override
  String get diagnosticsHint =>
      'Errors are kept on this phone only, with phone numbers removed. Copy the report if you want to share it with support.';

  @override
  String get noDiagnostics => 'No problems recorded';

  @override
  String get language => 'Language';
}
