package com.example.smart_dial

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.Icon
import android.net.Uri

/**
 * Launcher shortcuts that call a favorite: dynamic (long-press the app icon) and pinned
 * (home screen). Each opens MainActivity with [ACTION_CALL_SHORTCUT]; Flutter then places
 * the call so SIM preferences and permissions are applied the same way as in-app calls.
 */
object ShortcutsHelper {
    const val ACTION_CALL_SHORTCUT = "com.example.smart_dial.CALL_SHORTCUT"
    private const val MAX_DYNAMIC = 4

    data class Item(val id: String, val name: String, val number: String, val photoUri: String?)

    @Suppress("UNCHECKED_CAST")
    fun itemsFrom(raw: List<*>?): List<Item> = raw.orEmpty().mapNotNull { m ->
        (m as? Map<String, Any?>)?.let {
            val number = it["number"] as? String ?: return@let null
            Item("${it["id"]}", (it["name"] as? String) ?: number, number, it["photoUri"] as? String)
        }
    }

    private fun intentFor(ctx: Context, number: String) =
        Intent(ctx, MainActivity::class.java)
            .setAction(ACTION_CALL_SHORTCUT)
            .setData(Uri.fromParts("tel", number, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

    private fun build(ctx: Context, item: Item, rank: Int = 0): ShortcutInfo =
        ShortcutInfo.Builder(ctx, "fav_${item.id}_${item.number.hashCode()}")
            .setShortLabel(item.name.take(24))
            .setLongLabel(item.name)
            .setIcon(icon(ctx, item))
            .setIntent(intentFor(ctx, item.number))
            .setRank(rank)
            .build()

    fun setDynamic(ctx: Context, items: List<Item>) {
        val sm = ctx.getSystemService(ShortcutManager::class.java) ?: return
        val max = minOf(MAX_DYNAMIC, sm.maxShortcutCountPerActivity)
        sm.setDynamicShortcuts(items.take(max).mapIndexed { i, it -> build(ctx, it, i) })
    }

    fun pin(ctx: Context, item: Item): Boolean {
        val sm = ctx.getSystemService(ShortcutManager::class.java) ?: return false
        if (!sm.isRequestPinShortcutSupported) return false
        return sm.requestPinShortcut(build(ctx, item), null)
    }

    fun clear(ctx: Context) {
        ctx.getSystemService(ShortcutManager::class.java)?.removeAllDynamicShortcuts()
    }

    private fun icon(ctx: Context, item: Item): Icon {
        val photo = item.photoUri?.let {
            try {
                ctx.contentResolver.openInputStream(Uri.parse(it))?.use { BitmapFactory.decodeStream(it) }
            } catch (ignored: Exception) {
                null
            }
        }
        return Icon.createWithAdaptiveBitmap(photo?.let(::centered) ?: initials(item.name))
    }

    private const val SIZE = 216 // adaptive icon: 108dp @ 2x, inner 66% is the visible area

    private fun centered(src: Bitmap): Bitmap {
        val out = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val s = minOf(src.width, src.height)
        val sx = (src.width - s) / 2
        val sy = (src.height - s) / 2
        c.drawBitmap(src, android.graphics.Rect(sx, sy, sx + s, sy + s), android.graphics.Rect(0, 0, SIZE, SIZE), null)
        return out
    }

    private fun initials(name: String): Bitmap {
        val out = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(Color.rgb(0, 121, 107))
        val text = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2)
            .joinToString("") { it.substring(0, it.offsetByCodePoints(0, 1)).uppercase() }.ifEmpty { "#" }
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = SIZE * 0.28f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val y = SIZE / 2f - (p.descent() + p.ascent()) / 2f
        c.drawText(text, SIZE / 2f, y, p)
        return out
    }
}
