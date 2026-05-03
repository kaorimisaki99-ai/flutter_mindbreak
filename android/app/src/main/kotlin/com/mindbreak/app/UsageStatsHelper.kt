package com.mindbreak.app

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import java.util.Calendar

object UsageStatsHelper {

    /**
     * Returns all apps that appear in the device's app drawer (have a launcher icon).
     * This matches exactly what the user considers "an app" — including system apps
     * like Settings, Calculator, Camera, etc.
     * MindBreak itself is excluded.
     */
    fun getInstalledApps(context: Context): List<Map<String, String>> {
        val pm = context.packageManager

        val launchIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        return pm.queryIntentActivities(launchIntent, 0)
            .filter { it.activityInfo.packageName != context.packageName }
            .map { resolveInfo ->
                val name = resolveInfo.loadLabel(pm).toString()
                val pkg = resolveInfo.activityInfo.packageName
                mapOf("packageName" to pkg, "appName" to name)
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"] }
    }

    /**
     * Returns a map of packageName -> usedMinutesToday for all apps
     * that have been used today (since midnight).
     */
    fun getTopAppUsageToday(context: Context): Map<String, Int> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        ) ?: return emptyMap()

        val result = mutableMapOf<String, Int>()
        for (s in stats) {
            if (s.totalTimeInForeground > 0) {
                val minutes = (s.totalTimeInForeground / 1000 / 60).toInt()
                result[s.packageName] = minutes
            }
        }
        return result
    }

    /**
     * Returns the package name of the app with the most foreground time today.
     * Excludes system/launcher packages.
     */
    fun getTopPackageToday(context: Context): String? {
        val excludedPackages = setOf(
            "com.mindbreak.app",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.android.systemui",
            "com.sec.android.app.launcher",
        )

        return getTopAppUsageToday(context)
            .filter { (pkg, mins) -> pkg !in excludedPackages && mins > 0 }
            .maxByOrNull { it.value }
            ?.key
    }
}