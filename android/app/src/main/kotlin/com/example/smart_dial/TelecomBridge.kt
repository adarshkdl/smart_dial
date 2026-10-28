package com.example.smart_dial

import android.Manifest
import android.app.role.RoleManager
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.CallLog
import android.provider.ContactsContract
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import java.util.Locale

/**
 * Stateless access to Telecom and system providers. Provider queries are called from a
 * background executor by [MainActivity]; nothing here caches or persists system data.
 */
object TelecomBridge {

    private fun has(ctx: Context, perm: String) =
        ctx.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED

    fun isDefaultDialer(ctx: Context): Boolean {
        val rm = ctx.getSystemService(RoleManager::class.java) ?: return false
        return rm.isRoleAvailable(RoleManager.ROLE_DIALER) && rm.isRoleHeld(RoleManager.ROLE_DIALER)
    }

    fun isRoleAvailable(ctx: Context): Boolean =
        ctx.getSystemService(RoleManager::class.java)?.isRoleAvailable(RoleManager.ROLE_DIALER) == true

    fun countryIso(ctx: Context): String {
        val tm = ctx.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val iso = tm?.simCountryIso?.takeIf { it.isNotBlank() }
            ?: tm?.networkCountryIso?.takeIf { it.isNotBlank() }
            ?: Locale.getDefault().country
        return iso.uppercase(Locale.ROOT)
    }

    // ---- outgoing ----------------------------------------------------------

    /** Emergency numbers are passed through untouched; Telecom owns emergency routing. */
    @android.annotation.SuppressLint("MissingPermission")
    fun placeCall(ctx: Context, number: String, accountId: String?) {
        val tm = CallManager.telecom(ctx)
        val extras = Bundle()
        if (accountId != null) {
            findHandle(ctx, accountId)?.let { extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it) }
        }
        tm.placeCall(Uri.fromParts("tel", number, null), extras)
    }

    @android.annotation.SuppressLint("MissingPermission")
    private fun findHandle(ctx: Context, id: String): PhoneAccountHandle? {
        if (!has(ctx, Manifest.permission.READ_PHONE_STATE)) return null
        return try {
            CallManager.telecom(ctx).callCapablePhoneAccounts.firstOrNull { it.id == id }
        } catch (ignored: SecurityException) {
            null
        }
    }

    // ---- SIM / phone accounts ----------------------------------------------

    @android.annotation.SuppressLint("MissingPermission")
    fun phoneAccounts(ctx: Context): Map<String, Any?> {
        if (!has(ctx, Manifest.permission.READ_PHONE_STATE)) {
            return mapOf("accounts" to emptyList<Any>(), "defaultId" to null, "permitted" to false)
        }
        val tm = CallManager.telecom(ctx)
        return try {
            val list = tm.callCapablePhoneAccounts.mapIndexed { i, h ->
                val acc = tm.getPhoneAccount(h)
                mapOf(
                    "id" to h.id,
                    "label" to (acc?.label?.toString() ?: "SIM ${i + 1}"),
                    "slot" to i,
                )
            }
            val def = tm.getDefaultOutgoingPhoneAccount("tel")?.id
            mapOf("accounts" to list, "defaultId" to def, "permitted" to true)
        } catch (ignored: SecurityException) {
            mapOf("accounts" to emptyList<Any>(), "defaultId" to null, "permitted" to false)
        }
    }

    // ---- call log ----------------------------------------------------------

    fun callLog(ctx: Context, limit: Int): List<Map<String, Any?>> {
        val projection = arrayOf(
            CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME, CallLog.Calls.TYPE,
            CallLog.Calls.DATE, CallLog.Calls.DURATION, CallLog.Calls.PHONE_ACCOUNT_ID,
        )
        val args = Bundle().apply {
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${CallLog.Calls.DATE} DESC")
            putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
        }
        val out = ArrayList<Map<String, Any?>>()
        ctx.contentResolver.query(CallLog.Calls.CONTENT_URI, projection, args, null)?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "number" to (c.getString(1) ?: ""),
                        "name" to c.getString(2),
                        "type" to c.getInt(3),
                        "date" to c.getLong(4),
                        "duration" to c.getLong(5),
                        "accountId" to c.getString(6),
                    )
                )
            }
        }
        return out
    }

    fun deleteCallLog(ctx: Context, ids: List<String>): Int {
        if (ids.isEmpty()) return 0
        val placeholders = ids.joinToString(",") { "?" }
        return ctx.contentResolver.delete(CallLog.Calls.CONTENT_URI, "${CallLog.Calls._ID} IN ($placeholders)", ids.toTypedArray())
    }

    // ---- contacts ----------------------------------------------------------

    fun contacts(ctx: Context): List<Map<String, Any?>> {
        data class Acc(
            val id: String, var name: String, var photo: String?, var starred: Boolean,
            val phones: MutableList<Map<String, Any?>> = mutableListOf(), var company: String? = null,
        )
        val byId = LinkedHashMap<String, Acc>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.TYPE,
            ContactsContract.CommonDataKinds.Phone.LABEL,
            ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI,
            ContactsContract.CommonDataKinds.Phone.STARRED,
        )
        ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI, projection, null, null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY} COLLATE LOCALIZED ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0).toString()
                val acc = byId.getOrPut(id) { Acc(id, c.getString(1) ?: "", c.getString(5), c.getInt(6) == 1) }
                val number = c.getString(2) ?: continue
                val type = c.getInt(3)
                val label = ContactsContract.CommonDataKinds.Phone.getTypeLabel(ctx.resources, type, c.getString(4)).toString()
                if (acc.phones.none { it["number"] == number }) acc.phones.add(mapOf("number" to number, "label" to label))
            }
        }
        // Company names (optional search field)
        ctx.contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            arrayOf(ContactsContract.Data.CONTACT_ID, ContactsContract.CommonDataKinds.Organization.COMPANY),
            "${ContactsContract.Data.MIMETYPE} = ?",
            arrayOf(ContactsContract.CommonDataKinds.Organization.CONTENT_ITEM_TYPE), null,
        )?.use { c ->
            while (c.moveToNext()) {
                byId[c.getLong(0).toString()]?.company = c.getString(1)
            }
        }
        return byId.values.map {
            mapOf("id" to it.id, "name" to it.name, "photoUri" to it.photo, "starred" to it.starred,
                "phones" to it.phones, "company" to it.company)
        }
    }

    fun loadPhoto(ctx: Context, uri: String): ByteArray? = try {
        ctx.contentResolver.openInputStream(Uri.parse(uri))?.use { it.readBytes() }
    } catch (ignored: Exception) {
        null
    }
}
