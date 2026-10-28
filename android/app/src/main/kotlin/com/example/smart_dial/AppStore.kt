package com.example.smart_dial

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.provider.Settings

/**
 * App-owned data (settings, speed dial, SIM-per-contact) in app-private
 * SharedPreferences. android:allowBackup="false" keeps it off cloud backups.
 */
object AppStore {
    private const val PREFS = "smart_dial_app"
    private const val KEY = "app_data_v1"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Settings JSON, encrypted at rest (see [SecureStore]). */
    fun load(ctx: Context): String? = SecureStore.get(prefs(ctx), KEY)

    fun save(ctx: Context, json: String) = SecureStore.put(prefs(ctx), KEY, json)

    /** Named app-owned blobs (notes, diagnostics), encrypted at rest. */
    private fun blobKey(name: String) = "blob_" + name.filter { it.isLetterOrDigit() || it == '_' }

    fun loadBlob(ctx: Context, name: String): String? = SecureStore.get(prefs(ctx), blobKey(name))

    fun saveBlob(ctx: Context, name: String, json: String) = SecureStore.put(prefs(ctx), blobKey(name), json)

    /** Wipes everything Smart Dial stored: settings, notes, reminders (and their alarms), diagnostics, shortcuts. */
    fun clear(ctx: Context) {
        Reminders.cancelAll(ctx)
        prefs(ctx).edit().clear().apply()
        ShortcutsHelper.clear(ctx)
    }

    /** Android 12+ wallpaper-derived accent (Material You), else null. */
    fun dynamicAccent(ctx: Context): Int? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try { ctx.resources.getColor(android.R.color.system_accent1_500, ctx.theme) } catch (ignored: Exception) { null }
        } else null

    // ---- keypad tones --------------------------------------------------------

    private var toneGen: ToneGenerator? = null

    private val tones = mapOf(
        '0' to ToneGenerator.TONE_DTMF_0, '1' to ToneGenerator.TONE_DTMF_1, '2' to ToneGenerator.TONE_DTMF_2,
        '3' to ToneGenerator.TONE_DTMF_3, '4' to ToneGenerator.TONE_DTMF_4, '5' to ToneGenerator.TONE_DTMF_5,
        '6' to ToneGenerator.TONE_DTMF_6, '7' to ToneGenerator.TONE_DTMF_7, '8' to ToneGenerator.TONE_DTMF_8,
        '9' to ToneGenerator.TONE_DTMF_9, '*' to ToneGenerator.TONE_DTMF_S, '#' to ToneGenerator.TONE_DTMF_P,
    )

    /** Local keypad feedback tone; respects the system "dial pad tones" setting and silent mode. */
    fun playKeyTone(ctx: Context, digit: Char) {
        val tone = tones[digit] ?: return
        val systemOn = Settings.System.getInt(ctx.contentResolver, Settings.System.DTMF_TONE_WHEN_DIALING, 1) == 1
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (!systemOn || am.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        try {
            val gen = toneGen ?: ToneGenerator(AudioManager.STREAM_DTMF, 70).also { toneGen = it }
            gen.startTone(tone, 120)
        } catch (ignored: RuntimeException) {
            toneGen = null
        }
    }

    fun releaseTones() {
        toneGen?.release()
        toneGen = null
    }
}
