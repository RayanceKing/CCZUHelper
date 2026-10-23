package com.cczu.helper

import android.app.Application
import com.cczu.helper.di.AppContainer

class HelperApplication : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(applicationContext)
    }
}
