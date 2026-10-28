package com.example.smart_dial

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Call reminders: encrypted storage + AlarmManager scheduling. Native is the source of
 * truth so reminders fire with the app closed, survive reboot ([BootReceiver]) and can be
 * completed / snoozed straight from the notification ([ReminderReceiver]).
 */
object Reminders {
    private const val PREFS = "smart_dial_app"
    private const val KEY = "reminders_v1"
    private const val WINDOW_MS = 10 * 60 * 1000L

    data class Item(
        val id: String,
        val number: String,
        val name: String?,
        val dueAt: Long,
        val note: String?,
        val done: Boolean,
    ) {
        fun toMap(): Map<String, Any?> =
            mapOf("id" to id, "number" to number, "name" to name, "dueAt" to dueAt, "note" to note, "done" to done)

        fun toJson(): JSONObject = JSONObject().apply {
            put("id", id); put("number", number); put("name", name ?: JSONObject.NULL)
            put("dueAt", dueAt); put("note", note ?: JSONObject.NULL); put("done", done)
        }

        val notificationId: Int get() = 2000 + (id.hashCode() and 0x7ffffff)

        companion object {
            fun fromMap(m: Map<*, *>?): Item? {
                if (m == null) return null
                val id = m["id"] as? String ?: return null
                val number = m["number"] as? String ?: return null
                val due = (m["dueAt"] as? Number)?.toLong() ?: return null
                return Item(id, number, m["name"] as? String, due, m["note"] as? String, m["done"] == true)
            }

            fun fromJson(o: JSONObject): Item? = try {
                Item(
                    o.getString("id"), o.getString("number"),
                    if (o.isNull("name")) null else o.getString("name"),
                    o.getLong("dueAt"),
                    if (o.isNull("note")) null else o.getString("note"),
                    o.optBoolean("done", false),
                )
            } catch (ignored: Exception) {
                null
            }
        }
    }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun all(ctx: Context): List<Item> {
        val raw = SecureStore.get(prefs(ctx), KEY) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { Item.fromJson(arr.getJSONObject(it)) }
        } catch (ignored: Exception) {
            emptyList()
        }
    }

    @Synchronized
    private fun saveAll(ctx: Context, items: List<Item>) {
        val arr = JSONArray().apply { items.forEach { put(it.toJson()) } }
        SecureStore.put(prefs(ctx), KEY, arr.toString())
    }

    fun find(ctx: Context, id: String): Item? = all(ctx).firstOrNull { it.id == id }

    fun upsert(ctx: Context, item: Item) {
        saveAll(ctx, all(ctx).filter { it.id != item.id } + item)
        if (item.done) {
            cancel(ctx, item)
        } else {
            schedule(ctx, item)
        }
    }

    fun markDone(ctx: Context, id: String) {
        find(ctx, id)?.let { upsert(ctx, it.copy(done = true)) }
    }

    fun snooze(ctx: Context, id: String, minutes: Int) {
        find(ctx, id)?.let { upsert(ctx, it.copy(dueAt = System.currentTimeMillis() + minutes * 60_000L, done = false)) }
    }

    fun delete(ctx: Context, id: String) {
        find(ctx, id)?.let { cancel(ctx, it) }
        saveAll(ctx, all(ctx).filter { it.id != id })
    }

    /** Cancels every alarm and notification; storage itself is wiped by [AppStore.clear]. */
    fun cancelAll(ctx: Context) {
        all(ctx).forEach { cancel(ctx, it) }
    }

    fun rescheduleAll(ctx: Context) {
        all(ctx).filter { !it.done }.forEach { schedule(ctx, it) }
    }

    fun canScheduleExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return ctx.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    private fun alarmIntent(ctx: Context, item: Item): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, 0,
            Intent(ctx, ReminderReceiver::class.java)
                .setAction(ReminderReceiver.ACTION_FIRE)
                .setData(Uri.parse("smartdial://reminder/${Uri.encode(item.id)}"))
                .putExtra(ReminderReceiver.EXTRA_ID, item.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun schedule(ctx: Context, item: Item) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        // Overdue (e.g. after reboot) fires almost immediately.
        val at = maxOf(item.dueAt, System.currentTimeMillis() + 2_000L)
        val pi = alarmIntent(ctx, item)
        try {
            if (canScheduleExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                // Without the exact-alarm permission, fire within 10 minutes of the time.
                am.setWindow(AlarmManager.RTC_WAKEUP, at, WINDOW_MS, pi)
            }
        } catch (e: SecurityException) {
            am.setWindow(AlarmManager.RTC_WAKEUP, at, WINDOW_MS, pi)
        }
    }

    private fun cancel(ctx: Context, item: Item) {
        ctx.getSystemService(AlarmManager::class.java).cancel(alarmIntent(ctx, item))
        ctx.getSystemService(NotificationManager::class.java).cancel(item.notificationId)
    }
}
