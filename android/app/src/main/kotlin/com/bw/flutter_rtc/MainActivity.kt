package com.bw.flutter_rtc

import android.Manifest
import android.annotation.TargetApi
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
//    private val CHANNEL = "sendSms"
    private val REQUEST_SEND_SMS = 1
    private val CHANNEL = "com.bw.flutter_rtc"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger;
        if (messenger != null) {
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "send" -> {
                        val num = call.argument<String>("phone")
                        val msg = call.argument<String>("msg")
                        checkAndRequestSmsPermission(num, msg, result)
//                        sendSMS(num, msg, result)
                    }
                    "getPhoneNumber" -> {
                        val phoneNumber = getPhoneNumber()
                        if (phoneNumber != null) {
                            result.success(phoneNumber)
                        } else {
                            result.error("UNAVAILABLE", "Phone number not available.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP_MR1)
    private fun getPhoneNumber() : String? {
        var phoneNumber: String? = null
        val subscriptionManager =
            getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS) != PackageManager.PERMISSION_GRANTED  ||
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_STATE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_PHONE_NUMBERS, Manifest.permission.READ_PHONE_STATE), 1)
        } else {
            val activeSubscriptionInfoList = subscriptionManager.activeSubscriptionInfoList;

            if (activeSubscriptionInfoList != null && activeSubscriptionInfoList.isNotEmpty()) {
                for (subscriptionInfo in activeSubscriptionInfoList) {
                    phoneNumber = subscriptionInfo.number
                    Log.i("MainActivity", "Phone Number: $phoneNumber")
                }
            } else {
                // Handle the case where there are no active subscriptions
                Log.i("MainActivity", "No active subscriptions")
            }
        }
        return phoneNumber
    }

    private fun checkAndRequestSmsPermission(phoneNumber: String?, message: String?, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), REQUEST_SEND_SMS)
        } else {
            sendSMS(phoneNumber, message, result)
        }
    }

    @TargetApi(Build.VERSION_CODES.DONUT)
    private fun sendSMS(phoneNo: String?, msg: String?, result: MethodChannel.Result) {
        try {
            Log.i("sendSMS:", "phoneNo: " + phoneNo + "\nmsg: \n" + msg)
            val smsManager: SmsManager = getSystemService(SmsManager::class.java)
//            smsManager.sendTextMessage(phoneNo, null, msg, null, null)
            if (msg != null && msg.length > 160) {
                val parts = smsManager.divideMessage(msg)
                smsManager.sendMultipartTextMessage(phoneNo, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phoneNo, null, msg, null, null)
            }
            result.success("SMS Sent")
        } catch (ex: Exception) {
            ex.printStackTrace()
            result.error("Err", "Sms Not Sent", "")
        }
    }
}
