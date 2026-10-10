package com.cczu.helper.di

import android.content.Context
import com.cczu.helper.data.CourseStore
import com.cczu.helper.data.SessionManager
import com.cczu.helper.data.SettingsRepository
import com.cczu.helper.supabase.SupabaseApi
import com.cczu.helper.supabase.TeahouseRepository

/** 极简手工 DI 容器 */
class AppContainer(context: Context) {
    val settings: SettingsRepository = SettingsRepository(context)
    val courseStore: CourseStore = CourseStore(context)
    val session: SessionManager = SessionManager(context, settings)
    val supabase: SupabaseApi = SupabaseApi()
    val teahouse: TeahouseRepository = TeahouseRepository(supabase, settings)
}
