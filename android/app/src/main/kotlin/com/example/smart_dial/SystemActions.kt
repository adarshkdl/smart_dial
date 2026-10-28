package com.example.smart_dial

import android.Manifest
import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.CallLog
import android.provider.ContactsContract
import android.telecom.TelecomManager

/** Hand-offs to system apps and small provider writes. */
object SystemActions {

    private fun start(ctx: Context, i: Intent): Boolean = try {
        ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (ignored: ActivityNotFoundException) {
        false
    }

    fun sendMessage(ctx: Context, number: String) =
        start(ctx, Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null)))

    fun openContact(ctx: Context, contactId: String): Boolean {
        val id = contactId.toLongOrNull() ?: return false
        return start(ctx, Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, id)))
    }

    /** Opens the system "new contact" editor pre-filled; no write permission needed. */
    fun addContact(ctx: Context, number: String) = start(
        ctx,
        Intent(ContactsContract.Intents.Insert.ACTION)
            .setType(ContactsContract.RawContacts.CONTENT_TYPE)
            .putExtra(ContactsContract.Intents.Insert.PHONE, number),
    )

    /** Requires WRITE_CONTACTS; returns rows changed. */
    fun setStarred(ctx: Context, contactId: String, starred: Boolean): Int {
        val v = ContentValues().apply { put(ContactsContract.Contacts.STARRED, if (starred) 1 else 0) }
        return ctx.contentResolver.update(
            ContactsContract.Contacts.CONTENT_URI, v, "${ContactsContract.Contacts._ID} = ?", arrayOf(contactId),
        )
    }

    @SuppressLint("MissingPermission")
    fun callVoicemail(ctx: Context, accountId: String?) {
        val extras = Bundle()
        if (accountId != null && ctx.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            CallManager.telecom(ctx).callCapablePhoneAccounts.firstOrNull { it.id == accountId }
                ?.let { extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it) }
        }
        CallManager.telecom(ctx).placeCall(Uri.fromParts("voicemail", "", null), extras)
    }

    /**
     * Default dialers are expected to mark missed calls as seen once the user views them.
     * Needs WRITE_CALL_LOG; silently skipped without it.
     */
    fun markMissedCallsRead(ctx: Context): Int {
        CallNotifications.cancelMissed(ctx)
        if (ctx.checkSelfPermission(Manifest.permission.WRITE_CALL_LOG) != PackageManager.PERMISSION_GRANTED) return 0
        val v = ContentValues().apply {
            put(CallLog.Calls.NEW, 0)
            put(CallLog.Calls.IS_READ, 1)
        }
        return ctx.contentResolver.update(
            CallLog.Calls.CONTENT_URI, v,
            "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.NEW} = 1",
            arrayOf(CallLog.Calls.MISSED_TYPE.toString()),
        )
    }
}
