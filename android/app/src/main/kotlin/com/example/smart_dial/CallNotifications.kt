package com.example.smart_dial

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build

/** Incoming (full-screen intent) and ongoing-call notifications. Uses framework APIs only. */
object CallNotifications {
    private const val CHANNEL_INCOMING = "incoming_calls"
    private const val CHANNEL_ONGOING = "ongoing_calls"
    private const val ID_INCOMING = 1001
    private const val ID_ONGOING = 1002
    private const val CHANNEL_MISSED = "missed_calls"
    private const val ID_MISSED = 1003
    private var missedCount = 0

    private fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_INCOMING) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_INCOMING, ctx.getString(R.string.channel_incoming), NotificationManager.IMPORTANCE_HIGH).apply {
                    // Telecom plays the ringtone; the channel itself stays silent to avoid double ringing.
                    setSound(null, null)
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
        if (nm.getNotificationChannel(CHANNEL_ONGOING) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ONGOING, ctx.getString(R.string.channel_ongoing), NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    private fun canNotify(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun update(ctx: Context) {
        if (!canNotify(ctx)) return
        ensureChannels(ctx)
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val ringingId = CallManager.firstRingingId()
        if (ringingId != null) {
            nm.cancel(ID_ONGOING)
            nm.notify(ID_INCOMING, incoming(ctx, ringingId))
            return
        }
        nm.cancel(ID_INCOMING)
        val liveId = CallManager.firstLiveId()
        if (liveId != null) nm.notify(ID_ONGOING, ongoing(ctx, liveId)) else nm.cancel(ID_ONGOING)
    }

    fun cancelAll(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.cancel(ID_INCOMING)
        nm.cancel(ID_ONGOING)
    }

    private fun contentIntent(ctx: Context, req: Int): PendingIntent =
        PendingIntent.getActivity(ctx, req, MainActivity.callIntent(ctx), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun action(ctx: Context, action: String, callId: String, req: Int): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, req,
            Intent(ctx, CallActionReceiver::class.java).setAction(action).putExtra(CallActionReceiver.EXTRA_CALL_ID, callId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun title(callId: String): String {
        @Suppress("UNCHECKED_CAST")
        val call = (CallManager.snapshot()["calls"] as List<Map<String, Any?>>).firstOrNull { it["id"] == callId }
        return (call?.get("name") as String?) ?: (call?.get("number") as String?) ?: ""
    }

    private fun incoming(ctx: Context, callId: String): Notification =
        Notification.Builder(ctx, CHANNEL_INCOMING)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title(callId))
            .setContentText(ctx.getString(R.string.incoming_call))
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(contentIntent(ctx, 10))
            .setFullScreenIntent(contentIntent(ctx, 11), true)
            .addAction(Notification.Action.Builder(null as Icon?, ctx.getString(R.string.decline), action(ctx, CallActionReceiver.ACTION_DECLINE, callId, 12)).build())
            .addAction(Notification.Action.Builder(null as Icon?, ctx.getString(R.string.answer), action(ctx, CallActionReceiver.ACTION_ANSWER, callId, 13)).build())
            .build()

    private fun ongoing(ctx: Context, callId: String): Notification =
        Notification.Builder(ctx, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(title(callId))
            .setContentText(ctx.getString(R.string.ongoing_call))
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setUsesChronometer(true)
            .setContentIntent(contentIntent(ctx, 20))
            .addAction(Notification.Action.Builder(null as Icon?, ctx.getString(R.string.hang_up), action(ctx, CallActionReceiver.ACTION_HANGUP, callId, 21)).build())
            .build()

    // ---- missed calls ------------------------------------------------------

    fun missed(ctx: Context, number: String?, name: String?) {
        if (!canNotify(ctx)) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_MISSED) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_MISSED, ctx.getString(R.string.channel_missed), NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        missedCount++
        val who = name ?: number ?: ctx.getString(R.string.private_number)
        val b = Notification.Builder(ctx, CHANNEL_MISSED)
            .setSmallIcon(android.R.drawable.stat_notify_missed_call)
            .setCategory(Notification.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setNumber(missedCount)
            .setContentTitle(
                if (missedCount == 1) ctx.getString(R.string.missed_call)
                else ctx.getString(R.string.missed_calls_count, missedCount)
            )
            .setContentText(who)
            .setContentIntent(
                PendingIntent.getActivity(ctx, 30, MainActivity.recentsIntent(ctx), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )
            .setDeleteIntent(
                PendingIntent.getBroadcast(
                    ctx, 33, Intent(ctx, CallActionReceiver::class.java).setAction(CallActionReceiver.ACTION_MISSED_DISMISSED),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            )
        // Actions only make sense for a single, known number.
        if (missedCount == 1 && !number.isNullOrBlank()) {
            b.addAction(
                Notification.Action.Builder(
                    null as Icon?, ctx.getString(R.string.call_back),
                    PendingIntent.getBroadcast(
                        ctx, 31,
                        Intent(ctx, CallActionReceiver::class.java).setAction(CallActionReceiver.ACTION_CALL_BACK)
                            .putExtra(CallActionReceiver.EXTRA_NUMBER, number),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                ).build()
            )
            b.addAction(
                Notification.Action.Builder(
                    null as Icon?, ctx.getString(R.string.message),
                    PendingIntent.getActivity(
                        ctx, 32,
                        Intent(Intent.ACTION_SENDTO, android.net.Uri.fromParts("smsto", number, null)),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                ).build()
            )
        }
        nm.notify(ID_MISSED, b.build())
    }

    fun cancelMissed(ctx: Context) {
        missedCount = 0
        ctx.getSystemService(NotificationManager::class.java).cancel(ID_MISSED)
    }

    fun resetMissedCount() {
        missedCount = 0
    }
}
