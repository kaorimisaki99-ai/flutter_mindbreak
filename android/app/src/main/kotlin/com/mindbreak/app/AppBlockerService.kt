package com.mindbreak.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences

    // The package we most recently blocked. We only block each package ONCE
    // per "session" (until MindBreak is dismissed and the blocked app is
    // reopened) so we don't fire repeatedly on sub-window events.
    private var lastBlockedPackage: String? = null

    // Track whether MindBreak's own shield is currently showing so we
    // never intercept events while the user is already on the shield screen.
    private var mindBreakIsInForeground = false

    // Packages that must NEVER be intercepted regardless of the block list.
    // Blocking a launcher or system UI bricks the phone until reboot.
    private val systemSafePackages = setOf(
        // Launchers
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",       // Samsung
        "com.huawei.android.launcher",
        "com.miui.home",                       // Xiaomi
        "com.oppo.launcher",
        "com.vivo.launcher",
        "com.oneplus.launcher",
        "com.nothing.launcher",
        // System UI / core Android
        "com.android.systemui",
        "android",
        "com.android.settings",
        "com.android.phone",
        "com.google.android.packageinstaller",
        // Input methods (keyboard)
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        // Google Play Services & Store (blocking these causes cascading issues)
        "com.google.android.gms",
        "com.android.vending",
    )

    override fun onCreate() {
        super.onCreate()
        @Suppress("DEPRECATION")
        prefs = getSharedPreferences("mindbreak_blocker", Context.MODE_MULTI_PROCESS)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // 1. Never intercept system/launcher packages
        if (pkg in systemSafePackages) return

        // 2. MindBreak itself came to foreground — we're showing the shield
        //    or the user navigated back to us. Mark it and reset last blocked
        //    only if the shield was dismissed (handled by dismissShield()).
        if (pkg == packageName) {
            mindBreakIsInForeground = true
            return
        }

        // 3. Any other app came to foreground — MindBreak is no longer on top
        mindBreakIsInForeground = false

        // 4. Read the blocked list fresh each event (multi-process safe)
        val blockedPackages =
            prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

        // 5. Not in block list → allow
        if (pkg !in blockedPackages) return

        // 6. Already blocked this package this session → don't re-fire
        if (pkg == lastBlockedPackage) return

        // 7. Block it — bring MindBreak to the front
        lastBlockedPackage = pkg
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("shield_target", pkg)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        info.notificationTimeout = 100
        serviceInfo = info
    }

    companion object {
        fun isEnabled(context: Context): Boolean {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabledServices.split(':').any { it.contains(context.packageName) }
        }

        // Called by MainActivity when the user dismisses the shield so the
        // blocker knows it can intercept that package again next time.
        fun clearLastBlocked(context: Context) {
            val intent = Intent("com.mindbreak.app.CLEAR_LAST_BLOCKED")
            context.sendBroadcast(intent)
        }
    }
}