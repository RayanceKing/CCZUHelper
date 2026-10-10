package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.cczukit.dropCourses
import com.cczu.cczukit.getCurrentSelectableCourses
import com.cczu.cczukit.getCurrentTerm
import com.cczu.cczukit.selectCourses
import com.cczu.cczukit.models.SelectableCourse
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.UiState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.AsyncContent
import com.cczu.helper.ui.components.DetailScaffold
import kotlinx.coroutines.launch

@Composable
fun CourseSelectionScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<UiState<List<SelectableCourse>>>(UiState.Loading) }
    var selected by remember { mutableStateOf<Set<Int>>(emptySet()) }
    var working by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<String?>(null) }

    val load: suspend () -> Unit = {
        state = UiState.Loading
        runCatching {
            val app = container.session.require()
            app.getCurrentSelectableCourses()
        }.onSuccess { state = UiState.Success(it) }
            .onFailure { state = UiState.Error(it.readableMessage()) }
    }

    LaunchedEffect(Unit) { load() }

    DetailScaffold(
        title = "选课系统",
        onBack = { navController.popBackStack() },
        actions = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(
                    onClick = {
                        if (working) return@Button
                        working = true
                        scope.launch {
                            val current = (state as? UiState.Success)?.data ?: emptyList()
                            val chosen = current.filter { selected.contains(it.idn) }
                            runCatching {
                                val app = container.session.require()
                                val term = app.getCurrentTerm()
                                app.selectCourses(term = term, items = chosen)
                                "已提交 ${chosen.size} 门课程"
                            }.onSuccess {
                                result = it
                                selected = emptySet()
                                load()
                            }.onFailure { result = "选课失败：${it.readableMessage()}" }
                            working = false
                        }
                    },
                    enabled = selected.isNotEmpty() && !working,
                ) { Text("选课") }

                Button(
                    onClick = {
                        if (working) return@Button
                        working = true
                        scope.launch {
                            val current = (state as? UiState.Success)?.data ?: emptyList()
                            val ids = current
                                .filter { selected.contains(it.idn) && it.selectedId != 0 }
                                .map { it.selectedId }
                            runCatching {
                                val app = container.session.require()
                                app.dropCourses(selectedIds = ids)
                                "已退选 ${ids.size} 门课程"
                            }.onSuccess {
                                result = it
                                selected = emptySet()
                                load()
                            }.onFailure { result = "退课失败：${it.readableMessage()}" }
                            working = false
                        }
                    },
                    enabled = selected.isNotEmpty() && !working,
                ) { Text("退课") }
            }
        },
    ) { padding ->
        if (!account.isLoggedIn) {
            RequireLogin { navController.navigate(Routes.LOGIN) }
            return@DetailScaffold
        }
        Column(modifier = padding) {
            result?.let {
                Text(
                    text = it,
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            AsyncContent(
                state = state,
                onRetry = { scope.launch { load() } },
                emptyText = "当前没有可选课程",
                isEmpty = { it.isEmpty() },
            ) { courses ->
                LazyColumn(modifier = Modifier.fillMaxWidth()) {
                    items(courses, key = { it.idn }) { course ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Checkbox(
                                checked = selected.contains(course.idn),
                                onCheckedChange = { checked ->
                                    selected = if (checked) selected + course.idn else selected - course.idn
                                },
                            )
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = course.courseName, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    text = listOfNotNull(
                                        course.teacherName.takeIf { it.isNotBlank() },
                                        "${course.credits}学分",
                                        "容量 ${course.capacity}",
                                        course.selectionStatus.takeIf { it.isNotBlank() },
                                    ).joinToString(" · "),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}
