package com.cczu.helper

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.AppNav
import com.cczu.helper.ui.theme.CCZUHelperTheme

class MainActivity : ComponentActivity() {

    private lateinit var container: AppContainer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        container = (application as HelperApplication).container
        enableEdgeToEdge()
        setContent {
            CCZUHelperTheme {
                AppNav(container = container, onFinish = { finish() })
            }
        }
    }
}
