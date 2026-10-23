package com.cczu.helper.ui.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cczu.helper.data.AppSettingsState
import com.cczu.helper.data.ClassTimeManager
import com.cczu.helper.data.CourseEntity
import com.cczu.helper.data.parseHexColor
import java.time.LocalDate
import java.time.LocalTime

/** 一周的日期（按周起始日对齐） */
fun weekDates(base: LocalDate, offset: Int, weekStartDay: Int): List<LocalDate> {
    val target = base.plusWeeks(offset.toLong())
    val dayOfWeek = target.dayOfWeek.value // 1 = 周一 … 7 = 周日
    var daysFromStart = dayOfWeek - weekStartDay
    if (daysFromStart < 0) daysFromStart += 7
    val start = target.minusDays(daysFromStart.toLong())
    return (0..6).map { start.plusDays(it.toLong()) }
}

/** 第几周（以学期开始日为第 1 周） */
fun weekNumberOf(semesterStart: LocalDate, target: LocalDate, weekStartDay: Int): Int {
    fun weekStart(date: LocalDate): LocalDate {
        val dow = date.dayOfWeek.value
        var diff = dow - weekStartDay
        if (diff < 0) diff += 7
        return date.minusDays(diff.toLong())
    }
    val days = java.time.temporal.ChronoUnit.DAYS.between(weekStart(semesterStart), weekStart(target))
    return (days / 7 + 1).coerceAtLeast(1).toInt()
}

/** 星期名（按周起始日旋转） */
fun weekdayName(index: Int, weekStartDay: Int): String {
    val names = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
    return names[(index + weekStartDay - 1) % 7]
}

/** 课程在 7 列网格中的列索引 */
fun dayColumn(dayOfWeek: Int, weekStartDay: Int): Int {
    var index = (dayOfWeek - 1) - (weekStartDay - 1)
    if (index < 0) index += 7
    return index
}

private data class PlacedCourse(val course: CourseEntity, val column: Int, val columns: Int)

/** 同一天内重叠课程的并排布局 */
private fun layoutDay(courses: List<CourseEntity>): List<PlacedCourse> {
    val sorted = courses.sortedWith(compareBy({ it.timeSlot }, { it.duration }))
    val result = ArrayList<PlacedCourse>()
    var i = 0
    while (i < sorted.size) {
        val cluster = ArrayList<CourseEntity>()
        cluster.add(sorted[i])
        var j = i + 1
        while (j < sorted.size) {
            val next = sorted[j]
            val clusterEnd = cluster.maxOf { it.timeSlot + it.duration - 1 }
            if (next.timeSlot <= clusterEnd) {
                cluster.add(next)
                j += 1
            } else {
                break
            }
        }
        cluster.forEachIndexed { index, course -> result.add(PlacedCourse(course, index, cluster.size)) }
        i = j
    }
    return result
}

@Composable
fun ScheduleGrid(
    courses: List<CourseEntity>,
    settings: AppSettingsState,
    showCurrentTime: Boolean,
    onCourseClick: (CourseEntity) -> Unit,
    modifier: Modifier = Modifier,
) {
    val axisWidth: Dp = if (settings.showTimeRuler) 50.dp else 0.dp
    val startHour = settings.calendarStartHour
    val endHour = settings.calendarEndHour.coerceAtLeast(startHour + 1)
    val hourHeight: Dp = if (settings.timelineDisplayMode == 1) 120.dp else 60.dp
    val minuteHeight: Dp = hourHeight / 60f
    val gridHeight: Dp = minuteHeight * ((endHour - startHour) * 60)

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        val dayWidth: Dp = (maxWidth - axisWidth) / 7

        Row(modifier = Modifier.fillMaxWidth()) {
            if (settings.showTimeRuler) {
                TimeAxis(
                    width = axisWidth,
                    startHour = startHour,
                    endHour = endHour,
                    hourHeight = hourHeight,
                    classTimeMode = settings.timelineDisplayMode == 1,
                )
            }

            Box(modifier = Modifier.width(dayWidth * 7).height(gridHeight)) {
                if (settings.showGridLines) {
                    GridLines(
                        dayWidth = dayWidth,
                        startHour = startHour,
                        endHour = endHour,
                        hourHeight = hourHeight,
                        columns = 7,
                    )
                }

                val byDay = courses.groupBy { dayColumn(it.dayOfWeek, settings.weekStartDay) }
                byDay.forEach { (dayIndex, dayCourses) ->
                    layoutDay(dayCourses).forEach { placed ->
                        val startMinutes = ClassTimeManager.startMinutes(placed.course.timeSlot)
                        val durationMinutes = ClassTimeManager
                            .durationMinutes(placed.course.timeSlot, placed.course.duration)
                            .takeIf { it > 0 } ?: 90
                        val top = minuteHeight * (startMinutes - startHour * 60)
                        val left = dayWidth * dayIndex
                        val width = dayWidth / placed.columns
                        CourseBlock(
                            course = placed.course,
                            left = left + width * placed.column,
                            top = top,
                            width = width,
                            height = minuteHeight * durationMinutes,
                            opacity = settings.courseBlockOpacity,
                            onClick = { onCourseClick(placed.course) },
                        )
                    }
                }

                if (showCurrentTime && settings.showCurrentTimeline) {
                    val now = LocalTime.now()
                    val nowMinutes = now.hour * 60 + now.minute
                    if (nowMinutes >= startHour * 60 && nowMinutes <= endHour * 60) {
                        val top = minuteHeight * (nowMinutes - startHour * 60)
                        Box(
                            modifier = Modifier
                                .offset(y = top)
                                .padding(start = 0.dp)
                                .width(dayWidth * 7)
                                .height(2.dp)
                                .background(Color(0xFFE53935)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TimeAxis(
    width: Dp,
    startHour: Int,
    endHour: Int,
    hourHeight: Dp,
    classTimeMode: Boolean,
) {
    Box(modifier = Modifier.width(width)) {
        for (hour in startHour until endHour) {
            Box(modifier = Modifier.offset(y = hourHeight * (hour - startHour)).height(hourHeight)) {
                Text(
                    text = if (classTimeMode) {
                        val slot = ClassTimeManager.nearestSlot(hour * 60)
                        ClassTimeManager.forSlot(slot)?.let { "第${it.name}节" } ?: ""
                    } else {
                        String.format("%02d:00", hour)
                    },
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth(0.92f)
                        .align(Alignment.TopCenter)
                        .padding(top = 2.dp),
                )
            }
        }
    }
}

@Composable
private fun GridLines(
    dayWidth: Dp,
    startHour: Int,
    endHour: Int,
    hourHeight: Dp,
    columns: Int,
) {
    val lineColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
    for (hour in startHour..endHour) {
        Box(
            modifier = Modifier
                .offset(y = hourHeight * (hour - startHour))
                .width(dayWidth * columns)
                .height(1.dp)
                .background(lineColor),
        )
    }
    for (column in 0..columns) {
        Box(
            modifier = Modifier
                .offset(x = dayWidth * column)
                .width(1.dp)
                .height(hourHeight * (endHour - startHour))
                .background(lineColor),
        )
    }
}

@Composable
private fun CourseBlock(
    course: CourseEntity,
    left: Dp,
    top: Dp,
    width: Dp,
    height: Dp,
    opacity: Float,
    onClick: () -> Unit,
) {
    val base = Color(parseHexColor(course.color))
    val background = base.copy(alpha = opacity.coerceIn(0.15f, 1f))
    Box(
        modifier = Modifier
            .offset(x = left + 1.dp, y = top + 1.dp)
            .size(width = width - 2.dp, height = height - 2.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 3.dp, vertical = 2.dp),
    ) {
        CourseBlockText(
            name = course.name,
            location = course.location,
            teacher = course.teacher,
        )
    }
}

@Composable
private fun CourseBlockText(name: String, location: String, teacher: String) {
    androidx.compose.foundation.layout.Column {
        Text(
            text = name,
            fontSize = 11.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = Color.White,
        )
        if (location.isNotBlank()) {
            Text(
                text = location,
                fontSize = 10.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color.White.copy(alpha = 0.85f),
            )
        }
        if (teacher.isNotBlank()) {
            Text(
                text = teacher,
                fontSize = 10.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color.White.copy(alpha = 0.75f),
            )
        }
    }
}
