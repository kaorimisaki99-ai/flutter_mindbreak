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

        // Packages to always exclude regardless of system flag
        private val ALWAYS_EXCLUDED = setOf(
            "com.mindbreak.app",
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher",
            "com.miui.home",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.android.inputmethod.latin",
            "com.samsung.android.inputmethod",
            "com.google.android.inputmethod.latin",
            "android",
            "com.android.phone",
            "com.android.server.telecom",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsagePermission" -> result.success(hasUsageStatsPermission())

                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }

                    "getUsageStats" -> {
                        if (!hasUsageStatsPermission()) {
                            result.error("PERMISSION_DENIED", "Usage access not granted", null)
                            return@setMethodCallHandler
                        }
                        result.success(UsageStatsHelper.getTopAppUsageToday(applicationContext))
                    }

                    "hasAccessibilityPermission" ->
                        result.success(AppBlockerService.isEnabled(applicationContext))

                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "getInstalledApps" -> {
                        result.success(getAllNonSystemApps())
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

        // Use getLaunchIntentForPackage to find ALL apps that have a launcher icon
        // This catches both user-installed and pre-installed apps that appear in app drawer
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(
                PackageManager.ApplicationInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

        return packages
            .filter { appInfo ->
                val pkg = appInfo.packageName

                // Skip always-excluded packages
                if (pkg in ALWAYS_EXCLUDED) return@filter false

                // Skip packages with no launcher intent (background services, etc.)
                if (pm.getLaunchIntentForPackage(pkg) == null) return@filter false

                true
            }
            .mapNotNull { appInfo ->
                try {
                    val name = pm.getApplicationLabel(appInfo).toString()
                    if (name.isBlank()) return@mapNotNull null
                    mapOf("packageId" to appInfo.packageName, "name" to name)
                } catch (_: Exception) {
                    null
                }
            }
            .sortedBy { it["name"] }
    }
}