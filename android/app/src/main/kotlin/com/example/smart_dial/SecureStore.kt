package com.example.smart_dial

import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypts app-owned data at rest with AES-256-GCM. The key lives in the Android
 * Keystore (hardware-backed where available) and never leaves the device, so copied
 * preference files are unreadable elsewhere.
 *
 * Stored format: "e1:" + base64(iv[12] + ciphertext+tag). Values without the prefix are
 * legacy plaintext (written before Phase 3) and are re-encrypted on the next save.
 */
object SecureStore {
    private const val TAG = "SmartDialStore"
    private const val ALIAS = "smart_dial_data_v1"
    private const val PREFIX = "e1:"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    fun encrypt(plain: String): String {
        val c = Cipher.getInstance(TRANSFORMATION)
        c.init(Cipher.ENCRYPT_MODE, key())
        val out = c.iv + c.doFinal(plain.toByteArray(Charsets.UTF_8))
        return PREFIX + Base64.encodeToString(out, Base64.NO_WRAP)
    }

    /** Null when the value can't be decrypted (e.g. restored onto another device). */
    fun decrypt(stored: String): String? {
        if (!stored.startsWith(PREFIX)) return stored
        return try {
            val raw = Base64.decode(stored.substring(PREFIX.length), Base64.NO_WRAP)
            val c = Cipher.getInstance(TRANSFORMATION)
            c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw, 0, 12))
            String(c.doFinal(raw, 12, raw.size - 12), Charsets.UTF_8)
        } catch (e: Exception) {
            Log.w(TAG, "decrypt failed: ${e.javaClass.simpleName}")
            null
        }
    }

    fun get(prefs: SharedPreferences, key: String): String? = prefs.getString(key, null)?.let { decrypt(it) }

    fun put(prefs: SharedPreferences, key: String, value: String) {
        val stored = try {
            encrypt(value)
        } catch (e: Exception) {
            // Keystore unavailable (rare, broken devices): keep app-private plaintext rather than lose data.
            Log.w(TAG, "encrypt failed: ${e.javaClass.simpleName}")
            value
        }
        prefs.edit().putString(key, stored).apply()
    }
}
