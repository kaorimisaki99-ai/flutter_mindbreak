package com.mindbreak.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val USAGE_CHANNEL = "com.mindbreak.app/usage_stats"

        private val ALWAYS_EXCLUDED = setOf(
            "com.mindbreak.app",
            "com.android.systemui",
            "com.android.inputmethod.latin",
            "com.samsung.android.inputmethod",
            "com.google.android.inputmethod.latin",
            "android",
            "com.android.server.telecom",
            "com.android.shell",
            "com.android.providers.downloads.ui",
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
                        result.success(getAllAppsWithLauncher())
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

    private fun getAllAppsWithLauncher(): List<Map<String, String>> {
        val pm = packageManager

        // Query ALL activities that respond to MAIN + LAUNCHER
        // This is the most reliable way to get exactly what shows in the app drawer
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL
        } else {
            0
        }

        val resolveInfoList: List<ResolveInfo> = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(flags.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, flags)
            }
        } catch (e: Exception) {
            emptyList()
        }

        // Use LinkedHashMap to deduplicate by packageId while keeping best name
        val appMap = LinkedHashMap<String, String>()

        for (resolveInfo in resolveInfoList) {
            val pkg = resolveInfo.activityInfo?.packageName ?: continue
            if (pkg in ALWAYS_EXCLUDED) continue

            val name = try {
                resolveInfo.loadLabel(pm).toString().trim()
            } catch (e: Exception) {
                continue
            }

            if (name.isBlank()) continue

            // Keep first occurrence (usually the best label)
            if (!appMap.containsKey(pkg)) {
                appMap[pkg] = name
            }
        }

        return appMap.entries
            .map { mapOf("packageId" to it.key, "name" to it.value) }
            .sortedBy { it["name"] }
    }
}