package com.cczu.helper.ui.services

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.AccountState
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.SectionTitle

private data class ServiceItem(
    val title: String,
    val icon: ImageVector,
    val tint: Color,
    val route: String,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServicesScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val context = LocalContext.current

    val gridItems = listOf(
        ServiceItem("成绩查询", Icons.Filled.BarChart, Color(0xFF2196F3), Routes.GRADE),
        ServiceItem("学分绩点", Icons.Filled.Star, Color(0xFFFF9800), Routes.GPA),
        ServiceItem("考试安排", Icons.Filled.Event, Color(0xFF9C27B0), Routes.EXAM),
        ServiceItem("电费查询", Icons.Filled.Bolt, Color(0xFF4CAF50), Routes.ELECTRICITY),
        ServiceItem("一键评价", Icons.Filled.ThumbUp, Color(0xFFE91E63), Routes.EVALUATION),
        ServiceItem("培养方案", Icons.Filled.Description, Color(0xFF009688), Routes.TRAINING_PLAN),
    )

    val listItems = listOf(
        ServiceItem("选课系统", Icons.Filled.Checklist, Color(0xFF3F51B5), Routes.SELECTION),
    )

    fun open(route: String) {
        if (!account.isLoggedIn) {
            navController.navigate(Routes.LOGIN)
        } else {
            navController.navigate(route)
        }
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("服务") }) },
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding)) {
            item { SectionTitle("常用服务") }
            item {
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
                    gridItems.take(3).forEach { item ->
                        ServiceCard(item = item, modifier = Modifier.weight(1f)) { open(item.route) }
                    }
                }
            }
            item {
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp)) {
                    gridItems.drop(3).forEach { item ->
                        ServiceCard(item = item, modifier = Modifier.weight(1f)) { open(item.route) }
                    }
                }
            }
            item { SectionTitle("教务功能") }
            items(listItems.size) { index ->
                val item = listItems[index]
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
                            .clickable { open(item.route) }
                            .padding(horizontal = 14.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(item.icon, contentDescription = item.title, tint = item.tint)
                        Text(
                            text = item.title,
                            modifier = Modifier.padding(start = 12.dp),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            }
            item { SectionTitle("快捷入口") }
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    LinkCard("教务系统", Icons.Filled.Language, Color(0xFF2196F3), Modifier.weight(1f)) {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("http://jwqywx.cczu.edu.cn/")))
                    }
                    LinkCard("邮件系统", Icons.Filled.Language, Color(0xFFFF9800), Modifier.weight(1f)) {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.cczu.edu.cn/yxxt/list.htm")))
                    }
                    LinkCard("WebVPN", Icons.Filled.Language, Color(0xFF4CAF50), Modifier.weight(1f)) {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://zmvpn.cczu.edu.cn")))
                    }
                }
            }
            item { Spacer16() }
        }
    }
}

@Composable
private fun ServiceCard(item: ServiceItem, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .padding(6.dp)
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = item.icon,
            contentDescription = item.title,
            tint = item.tint,
            modifier = Modifier.size(28.dp),
        )
        Text(
            text = item.title,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}

@Composable
private fun LinkCard(
    title: String,
    icon: ImageVector,
    tint: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(icon, contentDescription = title, tint = tint, modifier = Modifier.size(26.dp))
        Text(text = title, fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun Spacer16() {
    androidx.compose.foundation.layout.Spacer(modifier = Modifier.size(16.dp))
}
