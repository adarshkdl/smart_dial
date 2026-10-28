package com.example.smart_dial

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.DisconnectCause
import android.telecom.InCallService
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import android.util.Log

/**
 * Single source of truth for live calls and audio state.
 *
 * Every change produces a full snapshot (all calls + audio), so listeners can never
 * apply a stale or duplicated delta. A new listener immediately receives the current
 * snapshot, which also restores the UI after Flutter engine / activity recreation.
 *
 * Privacy: never logs phone numbers or names — only call ids and state codes.
 */
object CallManager {
    private const val TAG = "SmartDialCalls"

    private val calls = LinkedHashMap<Call, String>()
    private val nameCache = HashMap<String, String?>()
    private var nextId = 1
    private var service: InCallService? = null
    private var audioState: CallAudioState? = null
    private var proximityLock: PowerManager.WakeLock? = null

    private val listeners = mutableSetOf<(Map<String, Any?>) -> Unit>()

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            Log.d(TAG, "call ${calls[call]} state=$state")
            publish()
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) = publish()
    }

    // ---- service lifecycle -------------------------------------------------

    fun attachService(s: InCallService) {
        service = s
    }

    fun detachService(s: InCallService) {
        if (service === s) {
            service = null
            releaseProximity()
        }
    }

    fun onCallAdded(call: Call) {
        val id = (nextId++).toString()
        calls[call] = id
        call.registerCallback(callback)
        Log.d(TAG, "call added id=$id state=${stateOf(call)}")
        publish()
    }

    fun onCallRemoved(call: Call) {
        call.unregisterCallback(callback)
        val ownerCtx = service
        if (ownerCtx != null && call.details.disconnectCause?.code == DisconnectCause.MISSED) {
            val number = call.details.handle?.schemeSpecificPart
            val name = calls[call]?.let { resolveName(ownerCtx, it, call, number) }
            CallNotifications.missed(ownerCtx, number, name)
        }
        val id = calls.remove(call)
        id?.let { nameCache.remove(it) }
        Log.d(TAG, "call removed id=$id")
        publish()
    }

    fun onAudioStateChanged(state: CallAudioState?) {
        audioState = state
        publish()
    }

    // ---- listeners ---------------------------------------------------------

    fun addListener(l: (Map<String, Any?>) -> Unit) {
        listeners.add(l)
        l(snapshot())
    }

    fun removeListener(l: (Map<String, Any?>) -> Unit) {
        listeners.remove(l)
    }

    fun hasRingingCall(): Boolean = calls.keys.any { stateOf(it) == Call.STATE_RINGING }
    fun hasCalls(): Boolean = calls.isNotEmpty()

    // ---- actions -----------------------------------------------------------

    private fun find(id: String?): Call? = calls.entries.firstOrNull { it.value == id }?.key

    fun answer(id: String?): Boolean = find(id)?.let { it.answer(VideoProfile.STATE_AUDIO_ONLY); true } ?: false
    fun reject(id: String?): Boolean = find(id)?.let { it.reject(false, null); true } ?: false
    fun disconnect(id: String?): Boolean = find(id)?.let { it.disconnect(); true } ?: false
    fun hold(id: String?): Boolean = find(id)?.let { it.hold(); true } ?: false
    fun unhold(id: String?): Boolean = find(id)?.let { it.unhold(); true } ?: false

    fun playDtmf(id: String?, digit: Char): Boolean = find(id)?.let { it.playDtmfTone(digit); true } ?: false
    fun stopDtmf(id: String?): Boolean = find(id)?.let { it.stopDtmfTone(); true } ?: false

    fun firstRingingId(): String? = calls.entries.firstOrNull { stateOf(it.key) == Call.STATE_RINGING }?.value
    fun firstLiveId(): String? = calls.entries.firstOrNull {
        val s = stateOf(it.key); s != Call.STATE_DISCONNECTED && s != Call.STATE_DISCONNECTING
    }?.value

    fun setMuted(muted: Boolean): Boolean = service?.let { it.setMuted(muted); true } ?: false

    @Suppress("DEPRECATION")
    fun setAudioRoute(route: Int): Boolean {
        val s = service ?: return false
        s.setAudioRoute(route)
        return true
    }

    // ---- snapshot ----------------------------------------------------------

    @Suppress("DEPRECATION")
    fun stateOf(call: Call): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) call.details.state else call.state

    fun snapshot(): Map<String, Any?> {
        val ctx = service
        val list = calls.map { (call, id) ->
            val d = call.details
            val number = d.handle?.schemeSpecificPart
            mapOf(
                "id" to id,
                "number" to number,
                "name" to resolveName(ctx, id, call, number),
                "state" to stateOf(call),
                "connectTimeMillis" to d.connectTimeMillis,
                "canHold" to d.can(Call.Details.CAPABILITY_HOLD),
                "canSwap" to d.can(Call.Details.CAPABILITY_SWAP_CONFERENCE),
                "canMute" to d.can(Call.Details.CAPABILITY_MUTE),
                "isConference" to d.hasProperty(Call.Details.PROPERTY_CONFERENCE),
                "disconnectLabel" to d.disconnectCause?.label?.toString(),
                "isIncoming" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        d.callDirection == Call.Details.DIRECTION_INCOMING),
            )
        }
        val a = audioState
        val audio = if (a == null) null else mapOf(
            "muted" to a.isMuted,
            "route" to a.route,
            "supportedRouteMask" to a.supportedRouteMask,
            "bluetoothName" to bluetoothName(a),
        )
        return mapOf("calls" to list, "audio" to audio)
    }

    /** Device name needs BLUETOOTH_CONNECT on Android 12+, which we don't request; degrade to null. */
    @android.annotation.SuppressLint("MissingPermission")
    private fun bluetoothName(a: CallAudioState): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try { a.activeBluetoothDevice?.name } catch (ignored: SecurityException) { null }
        } else null

    private fun resolveName(ctx: Context?, id: String, call: Call, number: String?): String? {
        if (nameCache.containsKey(id)) return nameCache[id]
        var name: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) name = call.details.contactDisplayName
        if (name.isNullOrBlank()) name = call.details.callerDisplayName
        if (name.isNullOrBlank() && ctx != null && !number.isNullOrBlank() &&
            ctx.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        ) {
            name = try {
                val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
                ctx.contentResolver.query(uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)
                    ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            } catch (e: Exception) {
                null
            }
        }
        val result = name?.takeIf { it.isNotBlank() }
        // Only cache once a lookup could have succeeded (number known).
        if (number != null) nameCache[id] = result
        return result
    }

    private fun publish() {
        updateProximity()
        service?.let { CallNotifications.update(it) }
        val snap = snapshot()
        listeners.toList().forEach { it(snap) }
    }

    // ---- proximity (screen off near ear) ----------------------------------

    private fun updateProximity() {
        val s = service ?: return
        val inCall = calls.keys.any {
            val st = stateOf(it); st == Call.STATE_ACTIVE || st == Call.STATE_DIALING || st == Call.STATE_CONNECTING
        }
        val earpiece = (audioState?.route ?: CallAudioState.ROUTE_EARPIECE) == CallAudioState.ROUTE_EARPIECE
        if (inCall && earpiece) acquireProximity(s) else releaseProximity()
    }

    private fun acquireProximity(ctx: Context) {
        if (proximityLock?.isHeld == true) return
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
        proximityLock = pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "smart_dial:proximity").also {
            it.setReferenceCounted(false)
            it.acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseProximity() {
        proximityLock?.let { if (it.isHeld) it.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY) }
        proximityLock = null
    }

    fun telecom(ctx: Context): TelecomManager = ctx.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
}
