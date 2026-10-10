package com.cczu.helper.data

/** 课表（对应 Swift 版 Schedule） */
data class ScheduleEntity(
    val id: String,
    val name: String,
    val termName: String,
    val createdAt: Long,
    val isActive: Boolean,
)

/** 课程（对应 Swift 版 Course） */
data class CourseEntity(
    val id: String,
    val name: String,
    val teacher: String,
    val location: String,
    val weeks: List<Int>,
    val dayOfWeek: Int,   // 1 = 周一 … 7 = 周日
    val timeSlot: Int,    // 开始节次
    val duration: Int,    // 连续节次数
    val color: String,    // #RRGGBB
    val scheduleId: String,
)

data class StoreSnapshot(
    val schedules: List<ScheduleEntity> = emptyList(),
    val courses: List<CourseEntity> = emptyList(),
)

/** 默认课程颜色池（与 iOS 版一致，保证同一课程颜色一致） */
val COURSE_COLORS = listOf(
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFD93D",
    "#FF9E9E", "#A8D8EA", "#FF90EE", "#98FB98", "#FFA500",
    "#87CEEB", "#F08080", "#20B2AA", "#FFB6C1", "#3CB371",
    "#DDA0DD", "#F7DC6F", "#BB8FCE", "#85C1E9", "#F8B88B",
)

/** DJB2 确定性哈希，保证同名课程颜色稳定 */
fun deterministicColor(forName: String): String {
    var hash = 5381u
    for (byte in forName.toByteArray()) {
        hash = ((hash shl 5) + hash) + byte.toUInt()
    }
    return COURSE_COLORS[(hash and 0x7FFFFFFFu).toInt() % COURSE_COLORS.size]
}

fun parseHexColor(hex: String): Int {
    val clean = hex.trim().removePrefix("#")
    return runCatching {
        when (clean.length) {
            6 -> (0xFF000000u or clean.toULong(16).toUInt()).toInt()
            8 -> clean.toULong(16).toInt()
            else -> 0xFF2196F3.toInt()
        }
    }.getOrDefault(0xFF2196F3.toInt())
}
