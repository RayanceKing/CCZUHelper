package com.cczu.helper.data

import com.cczu.cczukit.models.ParsedCourse

/**
 * 课表转换：把 CCZUKit 解析出的 [ParsedCourse] 合并为带节次时长的 [CourseEntity]
 * （对应 Swift 版 CourseTimeCalculator）
 */
object CourseTimeCalculator {

    fun generateCourses(
        parsedCourses: List<ParsedCourse>,
        scheduleId: String,
        colorOf: (String) -> String = ::deterministicColor,
    ): List<CourseEntity> {
        val grouped = LinkedHashMap<String, MutableList<ParsedCourse>>()
        for (course in parsedCourses) {
            val key = "${course.name}_${course.teacher}_${course.location}_${course.dayOfWeek}"
            grouped.getOrPut(key) { mutableListOf() }.add(course)
        }

        val result = ArrayList<CourseEntity>()
        for ((_, items) in grouped) {
            val sorted = items.sortedBy { it.timeSlot }
            var i = 0
            while (i < sorted.size) {
                val start = sorted[i]
                val startSlot = start.timeSlot
                var endSlot = startSlot
                var consumed = 1
                while (i + consumed < sorted.size && sorted[i + consumed].timeSlot == endSlot + 1) {
                    endSlot = sorted[i + consumed].timeSlot
                    consumed += 1
                }
                result.add(
                    CourseEntity(
                        id = "",
                        name = start.name,
                        teacher = start.teacher,
                        location = start.location,
                        weeks = start.weeks,
                        dayOfWeek = start.dayOfWeek,
                        timeSlot = startSlot,
                        duration = endSlot - startSlot + 1,
                        color = colorOf(start.name),
                        scheduleId = scheduleId,
                    )
                )
                i += consumed
            }
        }
        return result
    }
}
