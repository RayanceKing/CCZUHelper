package com.cczu.helper.ui.schedule

import android.content.Context
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.IcsConverter
import com.cczu.helper.di.AppContainer
import kotlinx.coroutines.launch
import java.io.File
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManageSchedulesScreen(container: AppContainer, navController: NavController) {
    val snapshot by container.courseStore.snapshot.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val context = LocalContext.current

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                val content = context.contentResolver
                    .openInputStream(uri)?.bufferedReader()?.readText().orEmpty()
                if (content.isBlank()) throw IllegalStateException("文件内容为空")
                val generated = IcsConverter.import(content, "")
                if (generated.isEmpty()) throw IllegalStateException("没有解析到课程")
                container.courseStore.addSchedule(
                    name = "ICS 导入 ${DateTimeFormatter.ofPattern("MM-dd HH:mm").format(LocalDateTime.now())}",
                    termName = "",
                    courses = generated,
                )
            }.onFailure {
                snackbar.showSnackbar("导入失败：${it.message ?: it.javaClass.simpleName}")
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("管理课表") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    TextButton(onClick = { importLauncher.launch("*/*") }) {
                        Text("导入 ICS")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (snapshot.schedules.isEmpty()) {
                item {
                    Text(
                        text = "还没有课表，返回课表页点右上角导入",
                        modifier = Modifier.padding(24.dp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            items(snapshot.schedules, key = { it.id }) { schedule ->
                val courses = snapshot.courses.filter { it.scheduleId == schedule.id }
                ScheduleRow(
                    name = schedule.name,
                    term = schedule.termName,
                    count = courses.size,
                    active = schedule.isActive,
                    onSelect = { scope.launch { container.courseStore.setActiveSchedule(schedule.id) } },
                    onExport = {
                        val ics = IcsConverter.export(schedule, courses, LocalDate.now())
                        shareText(context, "${schedule.name}.ics", ics)
                    },
                    onDelete = { scope.launch { container.courseStore.deleteSchedule(schedule.id) } },
                )
            }
        }
    }
}

@Composable
private fun ScheduleRow(
    name: String,
    term: String,
    count: Int,
    active: Boolean,
    onSelect: () -> Unit,
    onExport: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(checked = active, onCheckedChange = { if (it) onSelect() })
        Column(modifier = Modifier.weight(1f)) {
            Text(text = name, style = MaterialTheme.typography.bodyLarge)
            Text(
                text = "${term.ifBlank { "未命名学期" }} · ${count} 门课程",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        TextButton(onClick = onExport) { Text("导出") }
        TextButton(onClick = onDelete) { Text("删除") }
    }
}

private fun shareText(context: Context, fileName: String, content: String) {
    runCatching {
        val cache = File(context.cacheDir, "export").apply { mkdirs() }
        val file = File(cache, fileName)
        file.writeText(content)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/calendar"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "导出课表"))
    }
}
