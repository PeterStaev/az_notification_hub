package com.tangrainc.azure_notification_hub

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.lifecycle.Observer
import com.google.firebase.messaging.RemoteMessage
import com.microsoft.windowsazure.messaging.notificationhubs.InstallationTemplate
import com.microsoft.windowsazure.messaging.notificationhubs.NotificationHub
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.NewIntentListener


class AzureNotificationHubPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    NewIntentListener {
    companion object {
        const val SHARED_PREFERENCES_KEY = "fanh_shared_prefs"
        const val CALLBACK_DISPATCHER_HANDLE_KEY = "callback_dispatcher_handle"
        const val CALLBACK_HANDLE_KEY = "callback_handle"
        const val REMOTE_MESSAGE_FILE_KEY = "remote_message_file"
        const val DEFAULT_TEMPLATE_NAME = "FANH DEFAULT TEMPLATE"
    }

    private lateinit var channel: MethodChannel
    private var application: Application? = null
    private var mainActivity: Activity? = null
    private val remoteMessageLiveData = AzRemoteMessageLiveData.getInstance()
    private lateinit var remoteMessageObserver: Observer<RemoteMessage>
    private var initialMessage: RemoteMessage? = null;

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "plugins.flutter.io/azure_notification_hub"
        )
        channel.setMethodCallHandler(this)
        application = flutterPluginBinding.applicationContext as Application

        remoteMessageObserver = Observer { message ->
            channel.invokeMethod("AzNotificationHub.onMessage", message.toMap())
        }

        remoteMessageLiveData.observeForever(remoteMessageObserver)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        application = null
        remoteMessageLiveData.removeObserver(remoteMessageObserver)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mainActivity = binding.activity
        binding.addOnNewIntentListener(this)

        // This is for cases when the app is terminated and launched by clicking on a notification.
        if (mainActivity!!.intent != null && mainActivity!!.intent.extras != null) {
            if ((mainActivity!!.intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
                != Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY
            ) {
                try {
                    initialMessage = RemoteMessage(mainActivity!!.intent.extras!!)
                } catch (_: Exception) {
                    // DO NOTHING
                }
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        mainActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        mainActivity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        mainActivity = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        if (intent.extras == null) {
            return false
        }

        try {
            val remoteMessage = RemoteMessage(intent.extras!!)

            channel.invokeMethod("AzNotificationHub.onMessageOpenedApp", remoteMessage.toMap())

            mainActivity!!.intent = intent
            return true
        } catch (_: Exception) {
            return false
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "AzNotificationHub.start" -> startHubConnection(result)
            "AzNotificationHub.startWithHubInfo" -> startHubConnectionWithHubInfo(call.argument("connectionString")!!, call.argument("hubName")!!, result)
            "AzNotificationHub.addTags" -> addTags(call.argument("tags"), result)
            "AzNotificationHub.getTags" -> result.success(NotificationHub.getTags().toList())
            "AzNotificationHub.removeTags" -> removeTags(call.argument("tags"), result)
            "AzNotificationHub.clearTags" -> clearTags(result)
            "AzNotificationHub.setTemplate" -> setTemplate(call.argument("body")!!, result)
            "AzNotificationHub.removeTemplate" -> removeTemplate(result)
            "AzNotificationHub.startBackgroundIsolate" -> startBackgroundIsolate(
                call.argument("pluginCallbackHandle"),
                call.argument("userCallbackHandle"),
                result
            )
            "AzNotificationHub.getInitialMessage" -> getInitialMessage(result)
            "AzNotificationHub.getInstallationId" -> getInstallationId(result)
            "AzNotificationHub.getPushChannel" -> getPushChannel(result)
            "AzNotificationHub.setUserId" -> setUserId(call.argument("userId")!!, result)
            "AzNotificationHub.getUserId" -> getUserId(result)

            else -> result.notImplemented()
        }
    }

    private fun startHubConnection(result: Result) {
        if (application == null) {
            return
        }

        val metaData = application!!.packageManager.getApplicationInfo(
            application!!.packageName,
            PackageManager.GET_META_DATA
        ).metaData

        NotificationHub.start(
            application,
            metaData.getString("NotificationHubName"),
            metaData.getString("NotificationHubConnectionString")
        )
        NotificationHub.setListener(AzHubListener())

        result.success(null)
    }

    private fun startHubConnectionWithHubInfo(connectionString: String, hubName: String, result: Result) {
        if (application == null) {
            return
        }

        NotificationHub.start(
            application,
            hubName,
            connectionString
        )
        NotificationHub.setListener(AzHubListener())

        result.success(null)
    }

    private fun addTags(tags: Collection<String>?, result: Result) {
        val success = NotificationHub.addTags(tags)
        result.success(success)
    }

    private fun removeTags(tags: Collection<String>?, result: Result) {
        val success = NotificationHub.removeTags(tags)
        result.success(success)
    }

    private fun clearTags(result: Result) {
        NotificationHub.clearTags()

        result.success(null)
    }

    private fun setTemplate(body: String, result: Result) {
        val template = InstallationTemplate()
        template.body = body

        NotificationHub.setTemplate(DEFAULT_TEMPLATE_NAME, template)

        result.success(true)
    }

    private fun removeTemplate(result: Result) {
        val success = NotificationHub.removeTemplate(DEFAULT_TEMPLATE_NAME)
        result.success(success)
    }

    private fun startBackgroundIsolate(
        pluginCallbackHandle: Long?,
        userCallbackHandle: Long?,
        result: Result
    ) {
        application!!
            .getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
            .edit()
            .putLong(CALLBACK_DISPATCHER_HANDLE_KEY, pluginCallbackHandle!!)
            .putLong(CALLBACK_HANDLE_KEY, userCallbackHandle!!)
            .apply()

        result.success(null)
    }

    private fun getInitialMessage(result: Result) {
        result.success(initialMessage?.toMap())
        initialMessage = null
    }

    private fun getInstallationId(result: Result) {
        result.success(NotificationHub.getInstallationId())
    }

    private fun getPushChannel(result: Result) {
        result.success(NotificationHub.getPushChannel())
    }

    private fun setUserId(userId: String, result: Result) {
        val success = NotificationHub.setUserId(userId)
        result.success(success)
    }

    private fun getUserId(result: Result) {
        result.success(NotificationHub.getUserId())
    }
}
