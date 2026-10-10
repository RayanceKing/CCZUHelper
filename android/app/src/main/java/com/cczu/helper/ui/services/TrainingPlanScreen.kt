package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
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
import com.cczu.cczukit.getTrainingPlan
import com.cczu.cczukit.models.TrainingPlan
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.UiState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.AsyncContent
import com.cczu.helper.ui.components.DetailScaffold
import com.cczu.helper.ui.components.SectionTitle
import kotlinx.coroutines.launch

@Composable
fun TrainingPlanScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<UiState<TrainingPlan>>(UiState.Loading) }

    val load: suspend () -> Unit = {
        state = UiState.Loading
        runCatching {
            val app = container.session.require()
            app.getTrainingPlan()
        }.onSuccess { state = UiState.Success(it) }
            .onFailure { state = UiState.Error(it.readableMessage()) }
    }

    LaunchedEffect(Unit) { load() }

    DetailScaffold(title = "培养方案", onBack = { navController.popBackStack() }) { padding ->
        if (!account.isLoggedIn) {
            RequireLogin { navController.navigate(Routes.LOGIN) }
            return@DetailScaffold
        }
        AsyncContent(
            state = state,
            modifier = padding,
            onRetry = { scope.launch { load() } },
        ) { plan ->
            LazyColumn(modifier = Modifier.fillMaxWidth()) {
                item {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = plan.majorName, style = MaterialTheme.typography.titleLarge)
                        Text(
                            text = "${plan.degree} · 学制 ${plan.durationYears} 年",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(modifier = Modifier.padding(top = 12.dp)) {
                            CreditChip("总学分", plan.totalCredits)
                            CreditChip("必修", plan.requiredCredits)
                            CreditChip("选修", plan.electiveCredits)
                            CreditChip("实践", plan.practiceCredits)
                        }
                    }
                }
                plan.coursesBySemester.keys.sorted().forEach { semester ->
                    item { SectionTitle("第 ${semester} 学期") }
                    val courses = plan.coursesBySemester[semester] ?: emptyList()
                    items(courses.size) { index ->
                        val course = courses[index]
                        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)) {
                            Text(text = course.name, style = MaterialTheme.typography.bodyLarge)
                            Text(
                                text = "${course.code} · ${course.credits}学分 · ${typeName(course.type)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun CreditChip(label: String, value: Double) {
    Column(modifier = Modifier.padding(end = 16.dp)) {
        Text(text = label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = String.format("%.1f", value), style = MaterialTheme.typography.titleMedium)
    }
}

private fun typeName(type: com.cczu.cczukit.models.PlanCourseType): String = when (type) {
    com.cczu.cczukit.models.PlanCourseType.required -> "必修"
    com.cczu.cczukit.models.PlanCourseType.elective -> "选修"
    com.cczu.cczukit.models.PlanCourseType.practice -> "实践"
}
