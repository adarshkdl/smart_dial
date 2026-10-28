import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ml.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ml'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Dial'**
  String get appTitle;

  /// No description provided for @tabKeypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get tabKeypad;

  /// No description provided for @tabRecents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get tabRecents;

  /// No description provided for @tabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get tabContacts;

  /// No description provided for @defaultRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Make Smart Dial your phone app'**
  String get defaultRoleTitle;

  /// No description provided for @defaultRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Needed to answer calls and show the in-call screen. Until then, calls use your current phone app.'**
  String get defaultRoleBody;

  /// No description provided for @defaultRoleAction.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get defaultRoleAction;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @backspace.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get backspace;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @numberCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get numberCopied;

  /// No description provided for @enterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterNumber;

  /// No description provided for @errorInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid number'**
  String get errorInvalidNumber;

  /// No description provided for @errorCallPermission.
  ///
  /// In en, this message translates to:
  /// **'Phone permission is needed to place calls'**
  String get errorCallPermission;

  /// No description provided for @errorCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t place the call'**
  String get errorCallFailed;

  /// No description provided for @chooseSim.
  ///
  /// In en, this message translates to:
  /// **'Call with'**
  String get chooseSim;

  /// No description provided for @recentsPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'See your call history'**
  String get recentsPermissionTitle;

  /// No description provided for @recentsPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Smart Dial reads the call log on this phone to show recent calls. It never leaves your device.'**
  String get recentsPermissionBody;

  /// No description provided for @contactsPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'See your contacts'**
  String get contactsPermissionTitle;

  /// No description provided for @contactsPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Smart Dial reads contacts on this phone to show names and search. They never leave your device.'**
  String get contactsPermissionBody;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowAccess;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @permissionSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Access was turned off. You can enable it in Settings.'**
  String get permissionSettingsHint;

  /// No description provided for @noRecents.
  ///
  /// In en, this message translates to:
  /// **'No recent calls'**
  String get noRecents;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts on this phone'**
  String get noContacts;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noResults;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this list'**
  String get errorLoading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @searchRecents.
  ///
  /// In en, this message translates to:
  /// **'Search recents'**
  String get searchRecents;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get filterMissed;

  /// No description provided for @unknownNumber.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownNumber;

  /// No description provided for @privateNumber.
  ///
  /// In en, this message translates to:
  /// **'Private number'**
  String get privateNumber;

  /// No description provided for @callTypeIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get callTypeIncoming;

  /// No description provided for @callTypeOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get callTypeOutgoing;

  /// No description provided for @callTypeMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callTypeMissed;

  /// No description provided for @callTypeRejected.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get callTypeRejected;

  /// No description provided for @callTypeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get callTypeBlocked;

  /// No description provided for @callTypeVoicemail.
  ///
  /// In en, this message translates to:
  /// **'Voicemail'**
  String get callTypeVoicemail;

  /// No description provided for @deleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete from history'**
  String get deleteEntry;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @statusDialing.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get statusDialing;

  /// No description provided for @statusIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get statusIncoming;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get statusOnHold;

  /// No description provided for @statusEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get statusEnded;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get endCall;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @keypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get keypad;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @hideKeypad.
  ///
  /// In en, this message translates to:
  /// **'Hide keypad'**
  String get hideKeypad;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @onHoldWith.
  ///
  /// In en, this message translates to:
  /// **'On hold: {name}'**
  String onHoldWith(String name);

  /// No description provided for @incomingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Incoming: {name}'**
  String incomingWaiting(String name);

  /// No description provided for @callNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String callNumberLabel(String number);

  /// No description provided for @tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tabFavorites;

  /// No description provided for @rememberSim.
  ///
  /// In en, this message translates to:
  /// **'Remember for this number'**
  String get rememberSim;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get removeFavorite;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @errorFavoritePermission.
  ///
  /// In en, this message translates to:
  /// **'Contacts access is needed to change favorites'**
  String get errorFavoritePermission;

  /// No description provided for @openInContacts.
  ///
  /// In en, this message translates to:
  /// **'Open in Contacts'**
  String get openInContacts;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @addToHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Add to home screen'**
  String get addToHomeScreen;

  /// No description provided for @errorShortcut.
  ///
  /// In en, this message translates to:
  /// **'Your launcher doesn\'t support shortcuts'**
  String get errorShortcut;

  /// No description provided for @speedDialNotSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed dial {key} isn\'t set'**
  String speedDialNotSetTitle(int key);

  /// No description provided for @speedDialNotSetBody.
  ///
  /// In en, this message translates to:
  /// **'Assign a contact to call them by long-pressing this key.'**
  String get speedDialNotSetBody;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add to contacts'**
  String get addContact;

  /// No description provided for @showContactSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Show contact suggestions'**
  String get showContactSuggestions;

  /// No description provided for @speedDialAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed dial {key}'**
  String speedDialAssignTitle(int key);

  /// No description provided for @speedDialSaved.
  ///
  /// In en, this message translates to:
  /// **'Speed dial {key}: {name}'**
  String speedDialSaved(int key, String name);

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @frequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequent;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'Star contacts to see them here'**
  String get noFavorites;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get accentColor;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentDynamic.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get accentDynamic;

  /// No description provided for @keypadSize.
  ///
  /// In en, this message translates to:
  /// **'Keypad size'**
  String get keypadSize;

  /// No description provided for @sizeCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get sizeCompact;

  /// No description provided for @sizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get sizeNormal;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @t9Suggestions.
  ///
  /// In en, this message translates to:
  /// **'Smart search on keypad'**
  String get t9Suggestions;

  /// No description provided for @t9SuggestionsHint.
  ///
  /// In en, this message translates to:
  /// **'Match contacts by keypad letters and numbers as you type'**
  String get t9SuggestionsHint;

  /// No description provided for @keypadTones.
  ///
  /// In en, this message translates to:
  /// **'Dial pad tones'**
  String get keypadTones;

  /// No description provided for @keypadTonesHint.
  ///
  /// In en, this message translates to:
  /// **'Also follows the system setting and silent mode'**
  String get keypadTonesHint;

  /// No description provided for @keypadHaptics.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on keypress'**
  String get keypadHaptics;

  /// No description provided for @speedDial.
  ///
  /// In en, this message translates to:
  /// **'Speed dial'**
  String get speedDial;

  /// No description provided for @voicemail.
  ///
  /// In en, this message translates to:
  /// **'Voicemail'**
  String get voicemail;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @callsAndSim.
  ///
  /// In en, this message translates to:
  /// **'Calls & SIM'**
  String get callsAndSim;

  /// No description provided for @rememberSimSetting.
  ///
  /// In en, this message translates to:
  /// **'Remember SIM per contact'**
  String get rememberSimSetting;

  /// No description provided for @rememberSimHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No numbers remembered} =1{1 number remembered} other{{count} numbers remembered}}'**
  String rememberSimHint(int count);

  /// No description provided for @clearSimChoices.
  ///
  /// In en, this message translates to:
  /// **'Forget remembered SIM choices'**
  String get clearSimChoices;

  /// No description provided for @favoriteShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Favorites in app shortcuts'**
  String get favoriteShortcuts;

  /// No description provided for @favoriteShortcutsHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press the app icon to call up to 4 favorites'**
  String get favoriteShortcutsHint;

  /// No description provided for @isDefaultApp.
  ///
  /// In en, this message translates to:
  /// **'Smart Dial is your phone app'**
  String get isDefaultApp;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'Contacts and call history stay on this phone. Smart Dial only stores its own settings, notes, reminders and diagnostics — encrypted on this device, never backed up or uploaded.'**
  String get privacySummary;

  /// No description provided for @clearAppData.
  ///
  /// In en, this message translates to:
  /// **'Clear Smart Dial data'**
  String get clearAppData;

  /// No description provided for @clearAppDataHint.
  ///
  /// In en, this message translates to:
  /// **'Settings, speed dial, SIM choices, notes, reminders and diagnostics. Your contacts and call history are not affected.'**
  String get clearAppDataHint;

  /// No description provided for @clearAppDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all Smart Dial settings, speed dial entries, SIM choices, notes, reminders and diagnostics?'**
  String get clearAppDataConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @appDataCleared.
  ///
  /// In en, this message translates to:
  /// **'Smart Dial data cleared'**
  String get appDataCleared;

  /// No description provided for @filterDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get filterDeclined;

  /// No description provided for @allSims.
  ///
  /// In en, this message translates to:
  /// **'All SIMs'**
  String get allSims;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @remindIn15.
  ///
  /// In en, this message translates to:
  /// **'In 15 minutes'**
  String get remindIn15;

  /// No description provided for @remindIn1h.
  ///
  /// In en, this message translates to:
  /// **'In 1 hour'**
  String get remindIn1h;

  /// No description provided for @remindThisEvening.
  ///
  /// In en, this message translates to:
  /// **'This evening'**
  String get remindThisEvening;

  /// No description provided for @remindTomorrowMorning.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get remindTomorrowMorning;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me to call'**
  String get remindMe;

  /// No description provided for @pickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick date & time'**
  String get pickDateTime;

  /// No description provided for @reminderSetFor.
  ///
  /// In en, this message translates to:
  /// **'Reminder set: {time}'**
  String reminderSetFor(String time);

  /// No description provided for @reminderNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'Reminder saved, but notifications are off for Smart Dial'**
  String get reminderNoNotifications;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @exactAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'Reminders may arrive up to 10 minutes late. Allow exact alarms for on-time reminders.'**
  String get exactAlarmHint;

  /// No description provided for @allowExactAlarms.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allowExactAlarms;

  /// No description provided for @noReminders.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get noReminders;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @reminderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reminderDone;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write a note — only stored on this phone'**
  String get noteHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotes;

  /// No description provided for @remindToCallBack.
  ///
  /// In en, this message translates to:
  /// **'Remind me to call back'**
  String get remindToCallBack;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @copyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get copyReport;

  /// No description provided for @reportCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get reportCopied;

  /// No description provided for @diagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Errors are kept on this phone only, with phone numbers removed. Copy the report if you want to share it with support.'**
  String get diagnosticsHint;

  /// No description provided for @noDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'No problems recorded'**
  String get noDiagnostics;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ml'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ml':
      return AppLocalizationsMl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
