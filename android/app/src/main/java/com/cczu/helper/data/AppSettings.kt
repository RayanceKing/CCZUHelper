package com.cczu.helper.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.io.IOException

private val Context.settingsStore: DataStore<Preferences> by preferencesDataStore(name = "cczu_settings")
private val Context.accountStore: DataStore<Preferences> by preferencesDataStore(name = "cczu_account")

/** 界面相关设置（对应 Swift 版 AppSettings 的展示部分） */
data class AppSettingsState(
    val weekStartDay: Int = 1,
    val calendarStartHour: Int = 8,
    val calendarEndHour: Int = 21,
    val showGridLines: Boolean = true,
    val showTimeRuler: Boolean = true,
    val showCurrentTimeline: Boolean = true,
    val timeInterval: Int = 60,
    val courseBlockOpacity: Float = 0.5f,
    val timelineDisplayMode: Int = 0,
    val semesterStartDate: Long = 0L,
    val enableCourseNotification: Boolean = true,
    val enableExamNotification: Boolean = true,
)

/** 教务账号（登录态） */
data class AccountState(
    val username: String = "",
    val password: String = "",
    val displayName: String = "",
    val isLoggedIn: Boolean = false,
)

/** 茶楼账号（Supabase） */
data class TeahouseAccount(
    val email: String = "",
    val password: String = "",
    val userId: String = "",
    val accessToken: String = "",
    val refreshToken: String = "",
    val displayName: String = "",
)

class SettingsRepository(private val context: Context) {

    private object Keys {
        val WEEK_START_DAY = intPreferencesKey("weekStartDay")
        val CALENDAR_START_HOUR = intPreferencesKey("calendarStartHour")
        val CALENDAR_END_HOUR = intPreferencesKey("calendarEndHour")
        val SHOW_GRID_LINES = booleanPreferencesKey("showGridLines")
        val SHOW_TIME_RULER = booleanPreferencesKey("showTimeRuler")
        val SHOW_CURRENT_TIMELINE = booleanPreferencesKey("showCurrentTimeline")
        val TIME_INTERVAL = intPreferencesKey("timeInterval")
        val COURSE_BLOCK_OPACITY = floatPreferencesKey("courseBlockOpacity")
        val TIMELINE_DISPLAY_MODE = intPreferencesKey("timelineDisplayMode")
        val SEMESTER_START_DATE = longPreferencesKey("semesterStartDate")
        val ENABLE_COURSE_NOTIFICATION = booleanPreferencesKey("enableCourseNotification")
        val ENABLE_EXAM_NOTIFICATION = booleanPreferencesKey("enableExamNotification")

        val USERNAME = stringPreferencesKey("username")
        val PASSWORD = stringPreferencesKey("password")
        val DISPLAY_NAME = stringPreferencesKey("userDisplayName")
        val IS_LOGGED_IN = booleanPreferencesKey("isLoggedIn")

        val TH_EMAIL = stringPreferencesKey("teahouseEmail")
        val TH_PASSWORD = stringPreferencesKey("teahousePassword")
        val TH_USER_ID = stringPreferencesKey("teahouseUserId")
        val TH_ACCESS_TOKEN = stringPreferencesKey("teahouseAccessToken")
        val TH_REFRESH_TOKEN = stringPreferencesKey("teahouseRefreshToken")
        val TH_DISPLAY_NAME = stringPreferencesKey("teahouseDisplayName")
    }

    val settings: Flow<AppSettingsState> = context.settingsStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { p ->
            AppSettingsState(
                weekStartDay = p[Keys.WEEK_START_DAY] ?: 1,
                calendarStartHour = p[Keys.CALENDAR_START_HOUR] ?: 8,
                calendarEndHour = p[Keys.CALENDAR_END_HOUR] ?: 21,
                showGridLines = p[Keys.SHOW_GRID_LINES] ?: true,
                showTimeRuler = p[Keys.SHOW_TIME_RULER] ?: true,
                showCurrentTimeline = p[Keys.SHOW_CURRENT_TIMELINE] ?: true,
                timeInterval = p[Keys.TIME_INTERVAL] ?: 60,
                courseBlockOpacity = p[Keys.COURSE_BLOCK_OPACITY] ?: 0.5f,
                timelineDisplayMode = p[Keys.TIMELINE_DISPLAY_MODE] ?: 0,
                semesterStartDate = p[Keys.SEMESTER_START_DATE] ?: 0L,
                enableCourseNotification = p[Keys.ENABLE_COURSE_NOTIFICATION] ?: true,
                enableExamNotification = p[Keys.ENABLE_EXAM_NOTIFICATION] ?: true,
            )
        }

    val account: Flow<AccountState> = context.accountStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { p ->
            AccountState(
                username = p[Keys.USERNAME].orEmpty(),
                password = p[Keys.PASSWORD].orEmpty(),
                displayName = p[Keys.DISPLAY_NAME].orEmpty(),
                isLoggedIn = p[Keys.IS_LOGGED_IN] ?: false,
            )
        }

    val teahouseAccount: Flow<TeahouseAccount> = context.accountStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { p ->
            TeahouseAccount(
                email = p[Keys.TH_EMAIL].orEmpty(),
                password = p[Keys.TH_PASSWORD].orEmpty(),
                userId = p[Keys.TH_USER_ID].orEmpty(),
                accessToken = p[Keys.TH_ACCESS_TOKEN].orEmpty(),
                refreshToken = p[Keys.TH_REFRESH_TOKEN].orEmpty(),
                displayName = p[Keys.TH_DISPLAY_NAME].orEmpty(),
            )
        }

    suspend fun currentSettings(): AppSettingsState = settings.first()
    suspend fun currentAccount(): AccountState = account.first()
    suspend fun currentTeahouseAccount(): TeahouseAccount = teahouseAccount.first()

    suspend fun saveSettings(state: AppSettingsState) {
        context.settingsStore.edit { p ->
            p[Keys.WEEK_START_DAY] = state.weekStartDay
            p[Keys.CALENDAR_START_HOUR] = state.calendarStartHour
            p[Keys.CALENDAR_END_HOUR] = state.calendarEndHour
            p[Keys.SHOW_GRID_LINES] = state.showGridLines
            p[Keys.SHOW_TIME_RULER] = state.showTimeRuler
            p[Keys.SHOW_CURRENT_TIMELINE] = state.showCurrentTimeline
            p[Keys.TIME_INTERVAL] = state.timeInterval
            p[Keys.COURSE_BLOCK_OPACITY] = state.courseBlockOpacity
            p[Keys.TIMELINE_DISPLAY_MODE] = state.timelineDisplayMode
            p[Keys.SEMESTER_START_DATE] = state.semesterStartDate
            p[Keys.ENABLE_COURSE_NOTIFICATION] = state.enableCourseNotification
            p[Keys.ENABLE_EXAM_NOTIFICATION] = state.enableExamNotification
        }
    }

    suspend fun saveAccount(state: AccountState) {
        context.accountStore.edit { p ->
            p[Keys.USERNAME] = state.username
            p[Keys.PASSWORD] = state.password
            p[Keys.DISPLAY_NAME] = state.displayName
            p[Keys.IS_LOGGED_IN] = state.isLoggedIn
        }
    }

    suspend fun clearAccount() {
        val teahouse = currentTeahouseAccount()
        context.accountStore.edit { p ->
            p[Keys.USERNAME] = ""
            p[Keys.PASSWORD] = ""
            p[Keys.DISPLAY_NAME] = ""
            p[Keys.IS_LOGGED_IN] = false
            p[Keys.TH_EMAIL] = teahouse.email
            p[Keys.TH_PASSWORD] = teahouse.password
        }
    }

    suspend fun saveTeahouseAccount(state: TeahouseAccount) {
        context.accountStore.edit { p ->
            p[Keys.TH_EMAIL] = state.email
            p[Keys.TH_PASSWORD] = state.password
            p[Keys.TH_USER_ID] = state.userId
            p[Keys.TH_ACCESS_TOKEN] = state.accessToken
            p[Keys.TH_REFRESH_TOKEN] = state.refreshToken
            p[Keys.TH_DISPLAY_NAME] = state.displayName
        }
    }
}
