package com.cczu.helper.ui.login

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.cczu.cczukit.getStudentBasicInfo
import com.cczu.cczukit.login
import com.cczu.helper.data.AccountState
import com.cczu.helper.di.AppContainer
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(container: AppContainer, navController: NavController) {
    val scope = rememberCoroutineScope()
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = "龙城学伴", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "常州大学 · 校园助手",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(28.dp))

        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("学号") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(12.dp))
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("密码") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(20.dp))

        Button(
            onClick = {
                if (username.isBlank() || password.isBlank() || loading) return@Button
                loading = true
                errorMessage = null
                scope.launch {
                    runCatching {
                        container.session.configure(username.trim(), password)
                        val app = container.session.require()
                        val info = app.getStudentBasicInfo().message.firstOrNull()
                        val name = info?.name?.takeIf { it.isNotBlank() } ?: username.trim()
                        container.settings.saveAccount(
                            AccountState(
                                username = username.trim(),
                                password = password,
                                displayName = name,
                                isLoggedIn = true,
                            )
                        )
                    }.onSuccess {
                        loading = false
                        navController.popBackStack()
                    }.onFailure {
                        loading = false
                        errorMessage = describeError(it)
                    }
                }
            },
            enabled = username.isNotBlank() && password.isNotBlank() && !loading,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
        ) {
            if (loading) {
                CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
            } else {
                Text("登录")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = errorMessage ?: "使用教务系统账号登录，密码与正方教务系统一致",
            style = MaterialTheme.typography.bodySmall,
            color = if (errorMessage != null) MaterialTheme.colorScheme.error
            else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun describeError(error: Throwable): String {
    val raw = (error.message ?: "").lowercase()
    return when {
        "网络" in raw || "network" in raw || "timeout" in raw || "超时" in raw -> "网络异常，请检查校园网或 WebVPN 连接"
        "密码" in raw || "credentials" in raw || "账号" in raw -> "账号或密码错误"
        "未登录" in raw || "notloggedin" in raw -> "登录失败，请重试"
        else -> "登录失败：${error.message ?: error.javaClass.simpleName}"
    }
}
