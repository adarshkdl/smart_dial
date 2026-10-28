package com.example.smart_dial

import android.Manifest
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_SHOW_CALL = "show_call"
        const val EXTRA_OPEN_TAB = "open_tab"
        const val EXTRA_REMINDER_DONE = "reminder_done"
        private const val METHODS = "smart_dial/telecom"
        private const val EVENTS = "smart_dial/calls"
        private const val REQ_ROLE = 4101
        private const val REQ_PERMS = 4102

        fun callIntent(ctx: Context): Intent =
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_SHOW_CALL, true)
            }

        fun recentsIntent(ctx: Context): Intent =
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_OPEN_TAB, "recents")
            }

        private val PERMISSION_KEYS: Map<String, String> = buildMap {
            put("callPhone", Manifest.permission.CALL_PHONE)
            put("readCallLog", Manifest.permission.READ_CALL_LOG)
            put("writeCallLog", Manifest.permission.WRITE_CALL_LOG)
            put("readContacts", Manifest.permission.READ_CONTACTS)
            put("writeContacts", Manifest.permission.WRITE_CONTACTS)
            put("readPhoneState", Manifest.permission.READ_PHONE_STATE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) put("postNotifications", Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var methods: MethodChannel? = null
    private var pendingRole: MethodChannel.Result? = null
    private var pendingPerms: MethodChannel.Result? = null
    private var pendingPermKeys: List<String> = emptyList()
    private var initialIntent: Map<String, Any?>? = null
    private var callListener: ((Map<String, Any?>) -> Unit)? = null

    /** Reminder notification "Call" action: mark it done when the app opens to call. */
    private fun consumeReminderDone(i: Intent?) {
        val id = i?.getStringExtra(EXTRA_REMINDER_DONE) ?: return
        i.removeExtra(EXTRA_REMINDER_DONE)
        Reminders.markDone(this, id)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        consumeReminderDone(intent)
        initialIntent = payloadFrom(intent)
        super.onCreate(savedInstanceState)
        applyLockScreenFlags(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeReminderDone(intent)
        applyLockScreenFlags(intent)
        payloadFrom(intent)?.let { methods?.invokeMethod("onIntent", it) }
    }

    override fun onDestroy() {
        callListener?.let { CallManager.removeListener(it) }
        AppStore.releaseTones()
        io.shutdown()
        super.onDestroy()
    }

    /** DIAL / VIEW tel: → keypad; launcher shortcut → call; notification → open a tab. */
    private fun payloadFrom(i: Intent?): Map<String, Any?>? {
        if (i == null) return null
        i.getStringExtra(EXTRA_OPEN_TAB)?.let { return mapOf("action" to "openTab", "tab" to it) }
        val data = i.data
        val number = if (data?.scheme == "tel") data.schemeSpecificPart else null
        return when (i.action) {
            Intent.ACTION_DIAL, Intent.ACTION_VIEW -> number?.let { mapOf("action" to "dial", "number" to it) }
            ShortcutsHelper.ACTION_CALL_SHORTCUT -> number?.let { mapOf("action" to "call", "number" to it) }
            else -> null
        }
    }

    /** Show over the lock screen only while a call exists (permitted for the in-call UI). */
    private fun applyLockScreenFlags(i: Intent?) {
        val show = i?.getBooleanExtra(EXTRA_SHOW_CALL, false) == true || CallManager.hasCalls()
        setShowWhenLocked(show)
        setTurnScreenOn(show)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methods = MethodChannel(messenger, METHODS).also { it.setMethodCallHandler(::onMethod) }
        EventChannel(messenger, EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val l: (Map<String, Any?>) -> Unit = { snap ->
                    val noCalls = (snap["calls"] as? List<*>)?.isEmpty() ?: true
                    if (noCalls) {
                        setShowWhenLocked(false)
                        setTurnScreenOn(false)
                    }
                    events.success(snap)
                }
                callListener = l
                CallManager.addListener(l)
            }

            override fun onCancel(arguments: Any?) {
                callListener?.let { CallManager.removeListener(it) }
                callListener = null
            }
        })
    }

    // ---- method channel ----------------------------------------------------

    private fun onMethod(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        when (call.method) {
            "getAccessState" -> result.success(accessState())
            "requestDefaultDialer" -> requestRole(result)
            "requestPermissions" -> requestPerms(call.argument<List<String>>("permissions") ?: emptyList(), result)
            "openAppSettings" -> {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
                result.success(true)
            }
            "getInitialIntent" -> { result.success(initialIntent); initialIntent = null }
            "getCountryIso" -> result.success(TelecomBridge.countryIso(this))
            "placeCall" -> {
                val number = call.argument<String>("number")
                if (number.isNullOrBlank()) { result.error("invalid_number", "Empty number", null); return }
                guardCall(result) { TelecomBridge.placeCall(this, number, call.argument<String>("accountId")) }
            }
            "callVoicemail" -> guardCall(result) { SystemActions.callVoicemail(this, call.argument<String>("accountId")) }
            "getPhoneAccounts" -> background(result) { TelecomBridge.phoneAccounts(this) }
            "getCallLog" -> background(result) { TelecomBridge.callLog(this, call.argument<Int>("limit") ?: 500) }
            "deleteCallLogEntries" -> background(result) { TelecomBridge.deleteCallLog(this, call.argument<List<String>>("ids") ?: emptyList()) }
            "markMissedCallsRead" -> background(result) { SystemActions.markMissedCallsRead(this) }
            "getContacts" -> background(result) { TelecomBridge.contacts(this) }
            "loadPhoto" -> background(result) { TelecomBridge.loadPhoto(this, call.argument<String>("uri") ?: "") }
            "setStarred" -> background(result) {
                SystemActions.setStarred(this, call.argument<String>("contactId") ?: "", call.argument<Boolean>("starred") == true)
            }
            "sendMessage" -> result.success(SystemActions.sendMessage(this, call.argument<String>("number") ?: ""))
            "openContact" -> result.success(SystemActions.openContact(this, call.argument<String>("contactId") ?: ""))
            "addContact" -> result.success(SystemActions.addContact(this, call.argument<String>("number") ?: ""))
            // app-owned data
            "loadAppData" -> result.success(AppStore.load(this))
            "saveAppData" -> { AppStore.save(this, call.argument<String>("json") ?: "{}"); result.success(true) }
            "clearAppData" -> { AppStore.clear(this); result.success(true) }
            "loadBlob" -> background(result) { AppStore.loadBlob(this, call.argument<String>("name") ?: "") }
            "saveBlob" -> background(result) {
                AppStore.saveBlob(this, call.argument<String>("name") ?: "", call.argument<String>("json") ?: "{}"); true
            }
            // reminders (native is the source of truth)
            "getReminders" -> background(result) { Reminders.all(this).map { it.toMap() } }
            "saveReminder" -> background(result) {
                val item = Reminders.Item.fromMap(call.argument<Map<String, Any?>>("reminder"))
                    ?: throw IllegalArgumentException("bad reminder")
                Reminders.upsert(this, item); true
            }
            "deleteReminder" -> background(result) { Reminders.delete(this, call.argument<String>("id") ?: ""); true }
            "canScheduleExactAlarms" -> result.success(Reminders.canScheduleExact(this))
            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.fromParts("package", packageName, null)))
                    } catch (ignored: Exception) {}
                }
                result.success(true)
            }
            "getAppInfo" -> result.success(mapOf(
                "versionName" to (try { packageManager.getPackageInfo(packageName, 0).versionName } catch (ignored: Exception) { null }),
                "sdkInt" to Build.VERSION.SDK_INT,
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL,
            ))
            "getDynamicAccent" -> result.success(AppStore.dynamicAccent(this))
            "playKeyTone" -> { (call.argument<String>("digit") ?: "").firstOrNull()?.let { AppStore.playKeyTone(this, it) }; result.success(null) }
            // shortcuts
            "setAppShortcuts" -> background(result) {
                ShortcutsHelper.setDynamic(this, ShortcutsHelper.itemsFrom(call.argument<List<Any?>>("items"))); true
            }
            "pinShortcut" -> {
                val item = ShortcutsHelper.itemsFrom(listOf(call.argument<Map<String, Any?>>("item"))).firstOrNull()
                result.success(item != null && ShortcutsHelper.pin(this, item))
            }
            // in-call actions
            "answer" -> result.success(CallManager.answer(id))
            "reject" -> result.success(CallManager.reject(id))
            "disconnect" -> result.success(CallManager.disconnect(id))
            "hold" -> result.success(CallManager.hold(id))
            "unhold" -> result.success(CallManager.unhold(id))
            "playDtmf" -> result.success(CallManager.playDtmf(id, (call.argument<String>("digit") ?: "").firstOrNull() ?: '0'))
            "stopDtmf" -> result.success(CallManager.stopDtmf(id))
            "setMuted" -> result.success(CallManager.setMuted(call.argument<Boolean>("muted") == true))
            "setAudioRoute" -> result.success(CallManager.setAudioRoute(call.argument<Int>("route") ?: 1))
            else -> result.notImplemented()
        }
    }

    private fun guardCall(result: MethodChannel.Result, block: () -> Unit) {
        try {
            block()
            result.success(true)
        } catch (e: SecurityException) {
            result.error("permission_denied", "CALL_PHONE not granted", null)
        } catch (e: Exception) {
            result.error("call_failed", e.javaClass.simpleName, null)
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val v = work()
                main.post { result.success(v) }
            } catch (e: SecurityException) {
                main.post { result.error("permission_denied", e.javaClass.simpleName, null) }
            } catch (e: Exception) {
                main.post { result.error("query_failed", e.javaClass.simpleName, null) }
            }
        }
    }

    private fun accessState(): Map<String, Any?> = mapOf(
        "isDefaultDialer" to TelecomBridge.isDefaultDialer(this),
        "roleAvailable" to TelecomBridge.isRoleAvailable(this),
        "sdkInt" to Build.VERSION.SDK_INT,
        "permissions" to PERMISSION_KEYS.mapValues { (_, p) ->
            if (checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED) "granted" else "denied"
        } + (if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) mapOf("postNotifications" to "granted") else emptyMap()),
    )

    // ---- role --------------------------------------------------------------

    private fun requestRole(result: MethodChannel.Result) {
        if (TelecomBridge.isDefaultDialer(this)) { result.success(true); return }
        val rm = getSystemService(RoleManager::class.java)
        if (rm == null || !rm.isRoleAvailable(RoleManager.ROLE_DIALER)) { result.success(false); return }
        pendingRole?.success(false)
        pendingRole = result
        @Suppress("DEPRECATION")
        startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_DIALER), REQ_ROLE)
    }

    @Deprecated("Activity result API is not available on FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_ROLE) {
            pendingRole?.success(TelecomBridge.isDefaultDialer(this))
            pendingRole = null
        }
    }

    // ---- runtime permissions -----------------------------------------------

    private fun requestPerms(keys: List<String>, result: MethodChannel.Result) {
        val needed = keys.mapNotNull { k -> PERMISSION_KEYS[k]?.let { k to it } }
            .filter { (_, p) -> checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED }
        if (needed.isEmpty()) {
            result.success(keys.associateWith { "granted" })
            return
        }
        pendingPerms?.error("superseded", "Another permission request started", null)
        pendingPerms = result
        pendingPermKeys = keys
        requestPermissions(needed.map { it.second }.toTypedArray(), REQ_PERMS)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_PERMS) return
        val out = pendingPermKeys.associateWith { k ->
            val p = PERMISSION_KEYS[k]
            when {
                p == null -> "granted"
                checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED -> "granted"
                // Denied and the system will no longer show the dialog → user must use Settings.
                !shouldShowRequestPermissionRationale(p) -> "permanentlyDenied"
                else -> "denied"
            }
        }
        pendingPerms?.success(out)
        pendingPerms = null
    }
}
