package com.cczu.helper.ui.schedule

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.cczukit.CalendarParser
import com.cczu.cczukit.getCurrentClassSchedule
import com.cczu.cczukit.getCurrentTerm
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.AppSettingsState
import com.cczu.helper.data.ClassTimeManager
import com.cczu.helper.data.CourseEntity
import com.cczu.helper.data.CourseTimeCalculator
import com.cczu.helper.data.IcsConverter
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private const val PAGE_COUNT = 105
private const val PAGE_CENTER = 52

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ScheduleScreen(container: AppContainer, navController: NavController) {
    val snapshot by container.courseStore.snapshot.collectAsStateWithLifecycle()
    val settings by container.settings.settings.collectAsStateWithLifecycle(initialValue = AppSettingsState())
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())

    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }

    val pagerState = rememberPagerState(initialPage = PAGE_CENTER, pageCount = { PAGE_COUNT })
    var weekOffset by remember { mutableStateOf(0) }
    var importing by remember { mutableStateOf(false) }
    var selectedCourse by remember { mutableStateOf<CourseEntity?>(null) }

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            weekOffset = page - PAGE_CENTER
        }
    }

    val semesterStart = remember(settings.semesterStartDate) {
        if (settings.semesterStartDate <= 0L) LocalDate.now()
        else java.time.Instant.ofEpochMilli(settings.semesterStartDate)
            .atZone(java.time.ZoneId.systemDefault()).toLocalDate()
    }

    val activeSchedule = snapshot.schedules.firstOrNull { it.isActive } ?: snapshot.schedules.firstOrNull()
    val allCourses = activeSchedule?.let { snapshot.courses.filter { c -> c.scheduleId == it.id } } ?: emptyList()

    val today = LocalDate.now()
    val weekNumber = weekNumberOf(semesterStart, today.plusWeeks(weekOffset.toLong()), settings.weekStartDay)
    val weekCourses = allCourses.filter { it.weeks.contains(weekNumber) }
    val dates = weekDates(today, weekOffset, settings.weekStartDay)

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = DateTimeFormatter.ofPattern("yyyy年M月").format(today.plusWeeks(weekOffset.toLong())),
                            fontSize = 16.sp,
                        )
                        Text(
                            text = "第 ${weekNumber} 周",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                actions = {
                    TextButton(onClick = {
                        scope.launch { pagerState.animateScrollToPage(PAGE_CENTER) }
                    }) { Text("今天") }

                    IconButton(onClick = {
                        if (!account.isLoggedIn) {
                            navController.navigate(Routes.LOGIN)
                            return@IconButton
                        }
                        scope.launch {
                            importing = true
                            runCatching {
                                val app = container.session.require()
                                val matrix = app.getCurrentClassSchedule()
                                val parsed = CalendarParser.parseWeekMatrix(matrix)
                                val generated = CourseTimeCalculator.generateCourses(parsed, "")
                                if (generated.isEmpty()) {
                                    throw IllegalStateException("没有解析到课程")
                                }
                                container.courseStore.addSchedule(
                                    name = "教务课表 ${DateTimeFormatter.ofPattern("MM-dd HH:mm").format(java.time.LocalDateTime.now())}",
                                    termName = runCatching { app.getCurrentTerm() }.getOrDefault(""),
                                    courses = generated,
                                )
                            }.onFailure {
                                snackbar.showSnackbar("导入失败：${it.message ?: it.javaClass.simpleName}")
                            }
                            importing = false
                        }
                    }) {
                        Icon(Icons.Filled.Download, contentDescription = "导入课表")
                    }

                    IconButton(onClick = { navController.navigate(Routes.MANAGE_SCHEDULES) }) {
                        Icon(Icons.Filled.CalendarMonth, contentDescription = "管理课表")
                    }

                    IconButton(onClick = {
                        if (account.isLoggedIn) navController.navigate(Routes.USER_INFO)
                        else navController.navigate(Routes.LOGIN)
                    }) {
                        Icon(Icons.Filled.Person, contentDescription = "账号")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            WeekdayHeader(dates = dates, weekStartDay = settings.weekStartDay, showRuler = settings.showTimeRuler)

            if (importing) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else {
                HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
                    val offset = page - PAGE_CENTER
                    val pageWeek = weekNumberOf(semesterStart, today.plusWeeks(offset.toLong()), settings.weekStartDay)
                    val pageCourses = allCourses.filter { it.weeks.contains(pageWeek) }
                    ScheduleGrid(
                        courses = pageCourses,
                        settings = settings,
                        showCurrentTime = offset == 0,
                        onCourseClick = { selectedCourse = it },
                    )
                }
            }
        }
    }

    selectedCourse?.let { course ->
        AlertDialog(
            onDismissRequest = { selectedCourse = null },
            confirmButton = {
                TextButton(onClick = { selectedCourse = null }) { Text("关闭") }
            },
            title = { Text(course.name) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (course.teacher.isNotBlank()) Text("教师：${course.teacher}")
                    if (course.location.isNotBlank()) Text("地点：${course.location}")
                    Text("时间：${weekdayOf(course.dayOfWeek)} 第${course.timeSlot}节（${ClassTimeManager.timeRange(course.timeSlot)}）")
                    if (course.weeks.isNotEmpty()) Text("周次：${IcsConverter.formatWeekList(course.weeks)}")
                }
            },
        )
    }

    LaunchedEffect(weekCourses.size) { /* 保持网格随周次刷新 */ }
}

@Composable
private fun WeekdayHeader(dates: List<LocalDate>, weekStartDay: Int, showRuler: Boolean) {
    Row(modifier = Modifier.fillMaxWidth()) {
        if (showRuler) {
            Box(modifier = Modifier.width(50.dp))
        }
        Row(modifier = Modifier.weight(1f)) {
            val today = LocalDate.now()
            dates.forEachIndexed { index, date ->
                val isToday = date == today
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = 6.dp)
                        .background(
                            if (isToday) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                            else Color.Transparent
                        ),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = weekdayName(index, weekStartDay),
                        fontSize = 12.sp,
                        color = if (isToday) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = date.dayOfMonth.toString(),
                        fontSize = 14.sp,
                        color = if (isToday) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

private fun weekdayOf(dayOfWeek: Int): String =
    listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日").getOrElse(dayOfWeek - 1) { "" }
