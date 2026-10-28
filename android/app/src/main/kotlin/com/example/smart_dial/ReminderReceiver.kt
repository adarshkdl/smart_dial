package com.example.smart_dial

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build

/** Fires reminder notifications and handles Snooze / Done from them. */
class ReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_FIRE = "com.example.smart_dial.REMINDER_FIRE"
        const val ACTION_SNOOZE = "com.example.smart_dial.REMINDER_SNOOZE"
        const val ACTION_DONE = "com.example.smart_dial.REMINDER_DONE"
        const val EXTRA_ID = "reminder_id"
        private const val CHANNEL = "call_reminders"
        private const val SNOOZE_MINUTES = 10
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        when (intent.action) {
            ACTION_FIRE -> Reminders.find(context, id)?.takeIf { !it.done }?.let { notify(context, it) }
            ACTION_SNOOZE -> Reminders.snooze(context, id, SNOOZE_MINUTES)
            ACTION_DONE -> Reminders.markDone(context, id)
        }
    }

    private fun notify(ctx: Context, r: Reminders.Item) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, ctx.getString(R.string.channel_reminders), NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val reqBase = r.notificationId * 4

        // "Call" opens the app (no notification trampoline): Flutter places the call with the
        // usual SIM / permission handling and MainActivity marks the reminder done.
        val callIntent = Intent(ctx, MainActivity::class.java)
            .setAction(ShortcutsHelper.ACTION_CALL_SHORTCUT)
            .setData(Uri.fromParts("tel", r.number, null))
            .putExtra(MainActivity.EXTRA_REMINDER_DONE, r.id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        fun broadcast(action: String, req: Int) = PendingIntent.getBroadcast(
            ctx, req, Intent(ctx, ReminderReceiver::class.java).setAction(action).putExtra(EXTRA_ID, r.id), flags,
        )

        val n = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentTitle(ctx.getString(R.string.reminder_title, r.name ?: r.number))
            .setContentText(r.note ?: r.number)
            .setAutoCancel(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    ctx, reqBase,
                    Intent(ctx, MainActivity::class.java)
                        .putExtra(MainActivity.EXTRA_OPEN_TAB, "reminders")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    flags,
                )
            )
            .addAction(
                Notification.Action.Builder(null as Icon?, ctx.getString(R.string.reminder_call),
                    PendingIntent.getActivity(ctx, reqBase + 1, callIntent, flags)).build()
            )
            .addAction(
                Notification.Action.Builder(null as Icon?, ctx.getString(R.string.reminder_snooze),
                    broadcast(ACTION_SNOOZE, reqBase + 2)).build()
            )
            .addAction(
                Notification.Action.Builder(null as Icon?, ctx.getString(R.string.reminder_done),
                    broadcast(ACTION_DONE, reqBase + 3)).build()
            )
            .build()
        nm.notify(r.notificationId, n)
    }
}

/** Re-arms reminders after reboot, app update, or when exact-alarm permission changes. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" -> Reminders.rescheduleAll(context)
        }
    }
}
