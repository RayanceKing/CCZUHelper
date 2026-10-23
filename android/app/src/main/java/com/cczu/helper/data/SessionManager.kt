package com.cczu.helper.data

import android.content.Context
import com.cczu.cczukit.CCZUError
import com.cczu.cczukit.DefaultHttpClient
import com.cczu.cczukit.JwqywxApplication
import com.cczu.cczukit.login
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
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

    /**
     * 在 IO 线程上执行任意教务操作。
     *
     * cczukit 的多数数据接口（课表 / 成绩 / 考试 / 绩点 / 选课 / 评价 / 电费等）
     * 是**同步阻塞**的网络调用，若在 [Dispatchers.Main] 上直接调用会抛出
     * `NetworkOnMainThreadException`。（[require] / [login] 与登录后复用的基本信息
     * 走的是挂起函数或缓存，因此登录与个人资料不会触发该异常。）
     * 统一在此切到 [Dispatchers.IO]，避免每个调用点各自处理线程。
     */
    suspend fun <T> withApp(block: suspend (JwqywxApplication) -> T): T =
        withContext(Dispatchers.IO) { block(require()) }
}
