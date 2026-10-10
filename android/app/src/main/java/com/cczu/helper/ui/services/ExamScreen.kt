package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
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
import com.cczu.cczukit.getCurrentExamArrangements
import com.cczu.cczukit.models.ExamArrangement
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.UiState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.AsyncContent
import com.cczu.helper.ui.components.DetailScaffold
import kotlinx.coroutines.launch

@Composable
fun ExamScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<UiState<List<ExamArrangement>>>(UiState.Loading) }

    val load: suspend () -> Unit = {
        state = UiState.Loading
        runCatching {
            val app = container.session.require()
            app.getCurrentExamArrangements()
        }.onSuccess { state = UiState.Success(it) }
            .onFailure { state = UiState.Error(it.readableMessage()) }
    }

    LaunchedEffect(Unit) { load() }

    DetailScaffold(title = "考试安排", onBack = { navController.popBackStack() }) { padding ->
        if (!account.isLoggedIn) {
            RequireLogin { navController.navigate(Routes.LOGIN) }
            return@DetailScaffold
        }
        AsyncContent(
            state = state,
            modifier = padding,
            onRetry = { scope.launch { load() } },
            emptyText = "本学期暂无考试安排",
            isEmpty = { it.isEmpty() },
        ) { exams ->
            LazyColumn(modifier = Modifier.fillMaxWidth()) {
                items(exams) { exam ->
                    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                        Text(text = exam.courseName, style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = listOfNotNull(
                                exam.examTime?.takeIf { it.isNotBlank() },
                                exam.examLocation?.takeIf { it.isNotBlank() },
                                exam.examSeat?.let { "座位 $it" },
                            ).joinToString(" · "),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        if (!exam.remark.isNullOrBlank()) {
                            Text(
                                text = "备注：${exam.remark}",
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
