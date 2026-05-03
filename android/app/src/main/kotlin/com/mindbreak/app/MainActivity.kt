package com.mindbreak.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val USAGE_CHANNEL = "com.mindbreak.app/usage_stats"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "hasUsagePermission" -> {
                        result.success(hasUsageStatsPermission())
                    }

                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }

                    "getUsageStats" -> {
                        if (!hasUsageStatsPermission()) {
                            result.error("PERMISSION_DENIED", "Usage access not granted", null)
                            return@setMethodCallHandler
                        }
                        val stats = UsageStatsHelper.getTopAppUsageToday(applicationContext)
                        result.success(stats)
                    }

                    "getInstalledApps" -> {
                        val apps = UsageStatsHelper.getInstalledApps(applicationContext)
                        result.success(apps)
                    }

                    // Called by Flutter whenever the excluded-apps list changes.
                    // Writes blocked_packages into the SharedPreferences file that
                    // AppBlockerService reads so it immediately picks up the change.
                    "setBlockedPackages" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        val prefs = getSharedPreferences("mindbreak_blocker", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putStringSet("blocked_packages", packages.toSet())
                            .apply()
                        result.success(null)
                    }

                    "hasAccessibilityPermission" -> {
                        result.success(AppBlockerService.isEnabled(applicationContext))
                    }

                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}