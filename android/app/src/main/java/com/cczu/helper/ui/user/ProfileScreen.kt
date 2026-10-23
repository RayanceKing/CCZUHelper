package com.cczu.helper.ui.user

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.TeahouseAccount
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.SectionTitle
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(container: AppContainer, navController: NavController, onFinish: () -> Unit) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val teahouse by container.settings.teahouseAccount.collectAsStateWithLifecycle(initialValue = TeahouseAccount())
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("我的") },
                actions = {
                    androidx.compose.material3.IconButton(onClick = { navController.navigate(Routes.SETTINGS) }) {
                        Icon(Icons.Filled.Settings, contentDescription = "设置")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                shape = RoundedCornerShape(16.dp),
                tonalElevation = 1.dp,
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = if (account.isLoggedIn) account.displayName.ifBlank { account.username }
                            else "未登录教务系统",
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            text = if (account.isLoggedIn) "学号 ${account.username}" else "登录后可查询课表与成绩",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Button(onClick = {
                        if (account.isLoggedIn) navController.navigate(Routes.USER_INFO)
                        else navController.navigate(Routes.LOGIN)
                    }) {
                        Text(if (account.isLoggedIn) "查看" else "登录")
                    }
                }
            }

            SectionTitle("茶楼")
            MenuRow(title = if (teahouse.accessToken.isBlank()) "登录茶楼账号" else "茶楼：${teahouse.email}") {
                navController.navigate(Routes.TEAHOUSE_LOGIN)
            }

            SectionTitle("通用")
            MenuRow(title = "应用设置") { navController.navigate(Routes.SETTINGS) }

            if (account.isLoggedIn) {
                MenuRow(title = "退出登录", danger = true) {
                    scope.launch {
                        container.settings.clearAccount()
                        container.session.clear()
                    }
                }
            }
        }
    }
}

@Composable
private fun MenuRow(title: String, danger: Boolean = false, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                modifier = Modifier.weight(1f),
                color = if (danger) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = "›",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
