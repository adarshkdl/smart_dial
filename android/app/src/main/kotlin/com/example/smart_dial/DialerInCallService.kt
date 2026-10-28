package com.example.smart_dial

import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

/**
 * Bound by Telecom while this app is the default Phone app and at least one call exists.
 * Delegates all state to [CallManager]; brings the Flutter UI forward for non-ringing calls.
 * Ringing calls surface through a full-screen-intent notification (see [CallNotifications]),
 * which is the platform-supported way to show UI from the background / lock screen.
 */
class DialerInCallService : InCallService() {

    override fun onCreate() {
        super.onCreate()
        CallManager.attachService(this)
    }

    override fun onDestroy() {
        CallNotifications.cancelAll(this)
        CallManager.detachService(this)
        super.onDestroy()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallManager.onCallAdded(call)
        if (CallManager.stateOf(call) != Call.STATE_RINGING) {
            launchUi()
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        CallManager.onCallRemoved(call)
        if (!CallManager.hasCalls()) CallNotifications.cancelAll(this)
    }

    @Deprecated("Deprecated in API 34, still the only route callback on API 29-33")
    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        @Suppress("DEPRECATION")
        super.onCallAudioStateChanged(audioState)
        CallManager.onAudioStateChanged(audioState)
    }

    private fun launchUi() {
        try {
            startActivity(MainActivity.callIntent(this))
        } catch (ignored: Exception) {
            // Background-activity-start restrictions; the ongoing notification remains the entry point.
        }
    }
}
