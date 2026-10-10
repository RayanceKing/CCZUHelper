package com.cczu.helper.ui.teahouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeahouseLoginScreen(container: AppContainer, navController: NavController) {
    val scope = rememberCoroutineScope()
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSignUp) "注册茶楼账号" else "登录茶楼") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 28.dp, vertical = 24.dp)
                .fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top,
        ) {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("邮箱") },
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
                    if (email.isBlank() || password.isBlank() || loading) return@Button
                    loading = true
                    message = null
                    scope.launch {
                        runCatching {
                            if (isSignUp) container.teahouse.signUp(email.trim(), password)
                            else container.teahouse.signIn(email.trim(), password)
                        }.onSuccess {
                            if (isSignUp) {
                                runCatching { syncStudentProfile(container) }
                            }
                            loading = false
                            navController.popBackStack()
                        }.onFailure {
                            loading = false
                            message = "操作失败：${it.message ?: it.javaClass.simpleName}"
                        }
                    }
                },
                enabled = email.isNotBlank() && password.isNotBlank() && !loading,
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) {
                Text(if (loading) "处理中…" else (if (isSignUp) "注册" else "登录"))
            }

            TextButton(onClick = { isSignUp = !isSignUp }) {
                Text(if (isSignUp) "已有账号？去登录" else "还没有账号？去注册")
            }

            message?.let {
                Text(
                    text = it,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 16.dp),
                )
            }
        }
    }
}

/** 注册后把教务系统的学籍信息同步到茶楼 profiles */
private suspend fun syncStudentProfile(container: AppContainer) {
    val app = container.session.app ?: return
    val info = runCatching { app.getStudentBasicInfo().message.firstOrNull() }.getOrNull() ?: return
    val account = container.settings.currentTeahouseAccount()
    container.teahouse.registerStudentProfile(
        realName = info.name,
        studentId = info.studentNumber.ifBlank { info.studentId },
        className = info.className,
        grade = info.grade,
        collegeName = info.collegeName,
        username = account.email.substringBefore("@"),
        avatarUrl = null,
    )
}
