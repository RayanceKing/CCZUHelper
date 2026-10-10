package com.cczu.helper.data

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** 课程 ↔ ICS 日历的转换（导入 / 导出） */
object IcsConverter {

    private val stampFormatter = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss")

    /** 导出整张课表为 ICS 文本 */
    fun export(schedule: ScheduleEntity, courses: List<CourseEntity>, semesterStart: LocalDate): String {
        val builder = StringBuilder()
        builder.append("BEGIN:VCALENDAR\r\n")
        builder.append("VERSION:2.0\r\n")
        builder.append("PRODID:-//CCZUHelper//Android//CN\r\n")
        builder.append("CALSCALE:GREGORIAN\r\n")

        for (course in courses) {
            val start = ClassTimeManager.forSlot(course.timeSlot) ?: continue
            val end = ClassTimeManager.forSlot(course.timeSlot + course.duration - 1) ?: continue
            val dayOffset = (course.dayOfWeek - 1)
            val firstDate = semesterStart.plusDays(dayOffset.toLong())
            val dtStart = LocalDateTime.of(
                firstDate.year, firstDate.monthValue, firstDate.dayOfMonth,
                start.startHourInt, start.startMinute
            )
            val dtEnd = LocalDateTime.of(
                firstDate.year, firstDate.monthValue, firstDate.dayOfMonth,
                end.endHourInt, end.endMinute
            )
            val weeks = course.weeks
            if (weeks.isEmpty()) continue

            builder.append("BEGIN:VEVENT\r\n")
            builder.append("UID:${course.id}@cczu.helper\r\n")
            builder.append("DTSTAMP:${stampFormatter.format(LocalDateTime.now())}\r\n")
            builder.append("DTSTART:${stampFormatter.format(dtStart)}\r\n")
            builder.append("DTEND:${stampFormatter.format(dtEnd)}\r\n")
            builder.append("RRULE:FREQ=WEEKLY;COUNT=${weeks.size}\r\n")
            builder.append("SUMMARY:${escape(course.name)}\r\n")
            builder.append("LOCATION:${escape(course.location)}\r\n")
            if (course.teacher.isNotBlank()) {
                builder.append("DESCRIPTION:${escape("教师:${course.teacher}")}\r\n")
            }
            builder.append("END:VEVENT\r\n")
        }

        builder.append("END:VCALENDAR\r\n")
        return builder.toString()
    }

    /** 从 ICS 文本解析出课程（节次按最接近的作息时间匹配） */
    fun import(text: String, scheduleId: String): List<CourseEntity> {
        val result = ArrayList<CourseEntity>()
        val events = text.split("\r\nBEGIN:VEVENT", "\nBEGIN:VEVENT")
        val zone = ZoneId.systemDefault()

        for (event in events.drop(1)) {
            val body = event.substringBefore("\r\nEND:VEVENT").substringBefore("\nEND:VEVENT")
            val summary = unfold(body).lines()
                .firstOrNull { it.startsWith("SUMMARY") }?.substringAfter(":")?.trim().orEmpty()
            if (summary.isEmpty()) continue
            val location = unfold(body).lines()
                .firstOrNull { it.startsWith("LOCATION") }?.substringAfter(":")?.trim().orEmpty()
            val dtStartRaw = unfold(body).lines()
                .firstOrNull { it.startsWith("DTSTART") }?.substringAfter(":")?.trim().orEmpty()
            val dtEndRaw = unfold(body).lines()
                .firstOrNull { it.startsWith("DTEND") }?.substringAfter(":")?.trim().orEmpty()
            val rrule = unfold(body).lines()
                .firstOrNull { it.startsWith("RRULE") }?.substringAfter(":")?.trim().orEmpty()

            val start = parseDateTime(dtStartRaw) ?: continue
            val end = parseDateTime(dtEndRaw)
            val zoneDate = start.atZone(zone).toLocalDate()
            val dayOfWeek = isoDayOfWeek(zoneDate)
            val slot = ClassTimeManager.nearestSlot(start.hour * 60 + start.minute)
            val duration = if (end != null) {
                val endSlot = ClassTimeManager.nearestSlot(end.hour * 60 + end.minute)
                (endSlot - slot + 1).coerceIn(1, 12)
            } else {
                2
            }
            val weeks = parseRruleWeeks(rrule)

            result.add(
                CourseEntity(
                    id = "",
                    name = unescape(summary),
                    teacher = "",
                    location = unescape(location),
                    weeks = weeks,
                    dayOfWeek = dayOfWeek,
                    timeSlot = slot,
                    duration = duration,
                    color = deterministicColor(summary),
                    scheduleId = scheduleId,
                )
            )
        }
        return result
    }

    private fun unfold(text: String): String = text.replace("\r\n ", "").replace("\n ", "")

    private fun parseDateTime(raw: String): LocalDateTime? {
        val value = raw.trim()
        return runCatching {
            when {
                value.length >= 15 && value.contains("T") ->
                    LocalDateTime.parse(value.substring(0, 15), stampFormatter)
                value.length == 8 -> LocalDate.parse(value, DateTimeFormatter.BASIC_ISO_DATE).atStartOfDay()
                else -> null
            }
        }.getOrNull()
    }

    private fun parseRruleWeeks(rrule: String): List<Int> {
        val count = Regex("COUNT=(\\d+)").find(rrule)?.groupValues?.getOrNull(1)?.toIntOrNull()
        val until = Regex("UNTIL=(\\d{8})").find(rrule)?.groupValues?.getOrNull(1)
        return when {
            count != null -> (1..count).toList()
            until != null -> (1..25).toList()
            else -> (1..20).toList()
        }
    }

    /** java.time 的 DayOfWeek 即 1 = 周一 … 7 = 周日 */
    private fun isoDayOfWeek(date: LocalDate): Int = date.dayOfWeek.value

    private fun escape(value: String): String =
        value.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")

    private fun unescape(value: String): String =
        value.replace("\\n", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")

    fun formatWeekList(weeks: List<Int>): String {
        if (weeks.isEmpty()) return ""
        val sorted = weeks.sorted()
        val parts = ArrayList<String>()
        var start = sorted.first()
        var prev = sorted.first()
        for (week in sorted.drop(1)) {
            if (week == prev + 1) {
                prev = week
                continue
            }
            parts.add(if (start == prev) "$start" else "$start-$prev")
            start = week
            prev = week
        }
        parts.add(if (start == prev) "$start" else "$start-$prev")
        return parts.joinToString(",") { "${it}周" }
    }
}
