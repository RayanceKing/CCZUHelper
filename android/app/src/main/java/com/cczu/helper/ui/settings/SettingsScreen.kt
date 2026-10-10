package com.cczu.helper.ui.settings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.AppSettingsState
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.components.SectionCard
import com.cczu.helper.ui.components.SectionTitle
import com.cczu.helper.ui.components.SettingsSwitchRow
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(container: AppContainer, navController: NavController) {
    val settings by container.settings.settings.collectAsStateWithLifecycle(initialValue = AppSettingsState())
    val scope = rememberCoroutineScope()

    fun update(transform: (AppSettingsState) -> AppSettingsState) {
        scope.launch { container.settings.saveSettings(transform(settings)) }
    }

    val weekNames = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("设置") },
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
                .verticalScroll(rememberScrollState()),
        ) {
            SectionTitle("课表")
            SectionCard {
                DropdownRow(
                    title = "周起始日",
                    value = weekNames.getOrElse(settings.weekStartDay - 1) { "周一" },
                    options = weekNames,
                    onSelect = { name ->
                        update { it.copy(weekStartDay = weekNames.indexOf(name) + 1) }
                    },
                )
                DropdownRow(
                    title = "时间轴显示",
                    value = if (settings.timelineDisplayMode == 1) "课程节次" else "标准时间",
                    options = listOf("标准时间", "课程节次"),
                    onSelect = { name ->
                        update { it.copy(timelineDisplayMode = if (name == "课程节次") 1 else 0) }
                    },
                )
                SettingsSwitchRow(
                    title = "显示网格线",
                    checked = settings.showGridLines,
                    onCheckedChange = { update { s -> s.copy(showGridLines = it) } },
                )
                SettingsSwitchRow(
                    title = "显示时间标尺",
                    checked = settings.showTimeRuler,
                    onCheckedChange = { update { s -> s.copy(showTimeRuler = it) } },
                )
                SettingsSwitchRow(
                    title = "显示当前时间线",
                    checked = settings.showCurrentTimeline,
                    onCheckedChange = { update { s -> s.copy(showCurrentTimeline = it) } },
                )

                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text(
                        text = "课程块透明度 ${(settings.courseBlockOpacity * 100).toInt()}%",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Slider(
                        value = settings.courseBlockOpacity,
                        onValueChange = { update { s -> s.copy(courseBlockOpacity = it) } },
                        valueRange = 0.15f..1f,
                    )
                }

                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text(text = "学期开始日期", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        text = formatDate(settings.semesterStartDate),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    TextButton(onClick = {
                        update { it.copy(semesterStartDate = System.currentTimeMillis()) }
                    }) { Text("设为今天") }
                }
            }

            SectionTitle("提醒")
            SectionCard {
                SettingsSwitchRow(
                    title = "课程提醒",
                    checked = settings.enableCourseNotification,
                    onCheckedChange = { update { s -> s.copy(enableCourseNotification = it) } },
                )
                SettingsSwitchRow(
                    title = "考试提醒",
                    checked = settings.enableExamNotification,
                    onCheckedChange = { update { s -> s.copy(enableExamNotification = it) } },
                )
            }
        }
    }
}

@Composable
private fun DropdownRow(
    title: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        Text(text = title, modifier = Modifier.weight(1f))
        Box {
            TextButton(onClick = { expanded = true }) { Text(value) }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option) },
                        onClick = { onSelect(option); expanded = false },
                    )
                }
            }
        }
    }
}

private fun formatDate(millis: Long): String {
    if (millis <= 0L) return "未设置"
    return DateTimeFormatter.ofPattern("yyyy-MM-dd")
        .format(Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate())
}
