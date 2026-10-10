package com.cczu.helper.data

import android.content.Context
import com.cczu.cczukit.CCZUError
import com.cczu.cczukit.DefaultHttpClient
import com.cczu.cczukit.JwqywxApplication
import com.cczu.cczukit.login
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

/**
 * 教务会话：持有 [JwqywxApplication] 并保证登录态
 * （对应 Swift 版 AppSettings.configureJwqywx / ensureJwqywxLoggedIn）
 */
class SessionManager(
    private val context: Context,
    private val settings: SettingsRepository,
) {

    private val mutex = Mutex()

    @Volatile
    var app: JwqywxApplication? = null
        private set

    fun configure(username: String, password: String) {
        val client = DefaultHttpClient(username = username, password = password)
        app = JwqywxApplication(client, cacheDir = File(context.cacheDir, "CCZUKit"))
    }

    fun clear() {
        app = null
    }

    /** 返回已登录的教务实例；进程重启后自动用本地凭据恢复，仍无凭据时抛出 [CCZUError.NotLoggedIn] */
    suspend fun require(): JwqywxApplication = mutex.withLock {
        val current = app ?: restoreFromStore() ?: throw CCZUError.NotLoggedIn
        current.login()
        current
    }

    private suspend fun restoreFromStore(): JwqywxApplication? {
        val account = settings.currentAccount()
        if (!account.isLoggedIn || account.username.isBlank()) return null
        configure(account.username, account.password)
        return app
    }
}
