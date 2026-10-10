package com.cczu.helper.ui.user

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.cczu.cczukit.getStudentBasicInfo
import com.cczu.cczukit.models.StudentBasicInfo
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.InfoRow
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserInfoScreen(container: AppContainer, navController: NavController) {
    val scope = rememberCoroutineScope()
    var info by remember { mutableStateOf<StudentBasicInfo?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        runCatching { container.session.require().getStudentBasicInfo().message.firstOrNull() }
            .onSuccess { info = it }
            .onFailure { error = it.message ?: "加载失败" }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("个人信息") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).padding(vertical = 12.dp).fillMaxWidth()) {
            val data = info
            when {
                data != null -> {
                    InfoRow("姓名", data.name)
                    InfoRow("学号", data.studentNumber.ifBlank { data.studentId })
                    InfoRow("学院", data.collegeName)
                    InfoRow("专业", data.major)
                    InfoRow("班级", data.className)
                    InfoRow("年级", data.grade.toString())
                    InfoRow("校区", data.campus)
                    InfoRow("宿舍", data.dormitoryNumber)
                    InfoRow("学籍状态", data.studentStatus)
                }
                error != null -> Text(
                    text = error ?: "",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(16.dp),
                )
                else -> Text(text = "加载中…", modifier = Modifier.padding(16.dp))
            }

            Button(
                onClick = {
                    scope.launch {
                        container.settings.clearAccount()
                        container.session.clear()
                        navController.popBackStack()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text("退出登录")
            }
        }
    }
}
