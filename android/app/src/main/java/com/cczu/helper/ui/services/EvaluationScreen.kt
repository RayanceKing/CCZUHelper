package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
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
import com.cczu.cczukit.getCurrentEvaluatableClasses
import com.cczu.cczukit.getCurrentTerm
import com.cczu.cczukit.submitTeacherEvaluation
import com.cczu.cczukit.models.EvaluatableClass
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.UiState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.AsyncContent
import com.cczu.helper.ui.components.DetailScaffold
import kotlinx.coroutines.launch

/** 一键评价默认参数（与 iOS 版一致） */
private const val DEFAULT_OVERALL_SCORE = 90
private val DEFAULT_SCORES = listOf(100, 80, 100, 80, 100, 80)
private const val DEFAULT_COMMENT = "无"

@Composable
fun EvaluationScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<UiState<List<EvaluatableClass>>>(UiState.Loading) }
    var submitting by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<String?>(null) }

    val load: suspend () -> Unit = {
        state = UiState.Loading
        runCatching {
            val app = container.session.require()
            app.getCurrentEvaluatableClasses()
        }.onSuccess { state = UiState.Success(it) }
            .onFailure { state = UiState.Error(it.readableMessage()) }
    }

    LaunchedEffect(Unit) { load() }

    DetailScaffold(
        title = "一键评价",
        onBack = { navController.popBackStack() },
        actions = {
            Button(
                onClick = {
                    if (submitting) return@Button
                    submitting = true
                    scope.launch {
                        runCatching {
                            val app = container.session.require()
                            val term = app.getCurrentTerm()
                            val pending = app.getCurrentEvaluatableClasses()
                                .filter { it.evaluationStatus.isNullOrBlank() }
                            var success = 0
                            for (item in pending) {
                                runCatching {
                                    app.submitTeacherEvaluation(
                                        term = term,
                                        evaluatableClass = item,
                                        overallScore = DEFAULT_OVERALL_SCORE,
                                        scores = DEFAULT_SCORES,
                                        comments = DEFAULT_COMMENT,
                                    )
                                    success += 1
                                }
                            }
                            "已完成 $success/${pending.size} 门课程评价"
                        }.onSuccess {
                            result = it
                            load()
                        }.onFailure {
                            result = "评价失败：${it.readableMessage()}"
                        }
                        submitting = false
                    }
                },
                enabled = !submitting,
            ) {
                Text(if (submitting) "评价中…" else "一键评价")
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
                emptyText = "所有课程已评价",
                isEmpty = { it.isEmpty() },
            ) { classes ->
                LazyColumn(modifier = Modifier.fillMaxWidth()) {
                    items(classes) { item ->
                        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                            Text(text = item.courseName, style = MaterialTheme.typography.titleMedium)
                            Text(
                                text = "${item.teacherName} · ${item.courseCode}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                text = if (item.evaluationStatus.isNullOrBlank()) "待评价" else "已评价",
                                style = MaterialTheme.typography.bodySmall,
                                color = if (item.evaluationStatus.isNullOrBlank())
                                    MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                            )
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}
