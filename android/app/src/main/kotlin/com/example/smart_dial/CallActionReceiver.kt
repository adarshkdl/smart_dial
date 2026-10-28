package com.example.smart_dial

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Handles Answer / Decline / Hang up taps from call notifications without needing Flutter. */
class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ANSWER = "com.example.smart_dial.ANSWER"
        const val ACTION_DECLINE = "com.example.smart_dial.DECLINE"
        const val ACTION_HANGUP = "com.example.smart_dial.HANGUP"
        const val ACTION_CALL_BACK = "com.example.smart_dial.CALL_BACK"
        const val ACTION_MISSED_DISMISSED = "com.example.smart_dial.MISSED_DISMISSED"
        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_NUMBER = "number"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_CALL_ID)
        when (intent.action) {
            ACTION_ANSWER -> {
                CallManager.answer(id)
                try { context.startActivity(MainActivity.callIntent(context)) } catch (ignored: Exception) {}
            }
            ACTION_DECLINE -> CallManager.reject(id)
            ACTION_HANGUP -> CallManager.disconnect(id)
            ACTION_MISSED_DISMISSED -> CallNotifications.resetMissedCount()
            ACTION_CALL_BACK -> {
                CallNotifications.cancelMissed(context)
                val number = intent.getStringExtra(EXTRA_NUMBER) ?: return
                try {
                    TelecomBridge.placeCall(context, number, null)
                } catch (ignored: Exception) {
                    // No CALL_PHONE: open the keypad with the number instead.
                    try {
                        context.startActivity(
                            Intent(Intent.ACTION_DIAL, android.net.Uri.fromParts("tel", number, null))
                                .setClass(context, MainActivity::class.java)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    } catch (ignored2: Exception) {}
                }
            }
        }
    }
}
