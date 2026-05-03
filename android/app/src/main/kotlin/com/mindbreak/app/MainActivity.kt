package com.mindbreak.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
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

                    "hasAccessibilityPermission" -> {
                        result.success(AppBlockerService.isEnabled(applicationContext))
                    }

                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "getInstalledApps" -> {
                        // Returns ALL non-system apps — no special permission needed
                        val apps = getAllNonSystemApps()
                        result.success(apps)
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

    private fun getAllNonSystemApps(): List<Map<String, String>> {
        val pm = packageManager

        // Get all installed packages
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        }

        return packages
            .filter { appInfo ->
                // Keep only user-installed apps (exclude pure system apps)
                val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val isUpdatedSystem = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                // Include if: not system app OR is an updated system app (like Chrome, Maps)
                (!isSystem || isUpdatedSystem) && appInfo.packageName != packageName
            }
            .mapNotNull { appInfo ->
                try {
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    mapOf(
                        "packageId" to appInfo.packageName,
                        "name" to appName,
                    )
                } catch (e: Exception) {
                    null
                }
            }
            .filter { it["name"]!!.isNotBlank() }
            .sortedBy { it["name"] }
    }
}