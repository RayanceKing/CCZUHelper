package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.cczukit.getGrades
import com.cczu.cczukit.models.CourseGrade
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.UiState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.components.AsyncContent
import com.cczu.helper.ui.components.DetailScaffold
import com.cczu.helper.ui.components.SectionTitle
import kotlinx.coroutines.launch

@Composable
fun GradeScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<UiState<List<CourseGrade>>>(UiState.Loading) }

    val load: suspend () -> Unit = {
        state = UiState.Loading
        runCatching {
            val app = container.session.require()
            app.getGrades().message
        }.onSuccess { state = UiState.Success(it) }
            .onFailure { state = UiState.Error(it.readableMessage()) }
    }

    LaunchedEffect(Unit) { load() }

    DetailScaffold(title = "成绩查询", onBack = { navController.popBackStack() }) { padding ->
        if (!account.isLoggedIn) {
            RequireLogin { navController.navigate(com.cczu.helper.ui.Routes.LOGIN) }
            return@DetailScaffold
        }
        AsyncContent(
            state = state,
            modifier = padding,
            onRetry = { scope.launch { load() } },
            emptyText = "暂无成绩数据",
            isEmpty = { it.isEmpty() },
        ) { grades ->
            val grouped = grades.groupBy { it.term }
            LazyColumn(modifier = Modifier.fillMaxWidth()) {
                grouped.keys.sortedDescending().forEach { term ->
                    item { SectionTitle("第 ${term} 学期") }
                    items(grouped[term] ?: emptyList()) { grade ->
                        GradeRow(grade = grade)
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun GradeRow(grade: CourseGrade) {
    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = grade.courseName, style = MaterialTheme.typography.bodyLarge)
            Text(
                text = "${grade.courseTypeName} · ${grade.courseCredits}学分 · ${grade.teacherName}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Column(horizontalAlignment = androidx.compose.ui.Alignment.End) {
            Text(text = grade.grade.toString(), style = MaterialTheme.typography.titleMedium)
            Text(
                text = "绩点 ${grade.gradePoints}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
