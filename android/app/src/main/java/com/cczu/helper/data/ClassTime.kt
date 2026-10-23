package com.cczu.helper.data

/** 一节课的时间配置（对应 Swift 版 ClassTimeConfig） */
data class ClassTimeConfig(
    val slotNumber: Int,
    val name: String,
    val startTime: String, // HHmm
    val endTime: String,   // HHmm
) {
    val startTimeInMinutes: Int
        get() = toMinutes(startTime)

    val endTimeInMinutes: Int
        get() = toMinutes(endTime)

    val startHourInt: Int get() = startTime.take(2).toIntOrNull() ?: 0
    val startMinute: Int get() = startTime.takeLast(2).toIntOrNull() ?: 0
    val endHourInt: Int get() = endTime.take(2).toIntOrNull() ?: 0
    val endMinute: Int get() = endTime.takeLast(2).toIntOrNull() ?: 0

    fun formatRange(): String = "${format(startTime)}-${format(endTime)}"

    private fun toMinutes(value: String): Int {
        if (value.length != 4) return 0
        return (value.take(2).toIntOrNull() ?: 0) * 60 + (value.takeLast(2).toIntOrNull() ?: 0)
    }

    private fun format(value: String): String =
        if (value.length == 4) "${value.take(2)}:${value.takeLast(2)}" else value
}

/** 课程时间统一管理（对应 Swift 版 ClassTimeManager） */
object ClassTimeManager {

    private val classTimes: List<ClassTimeConfig> = listOf(
        ClassTimeConfig(1, "1", "0800", "0840"),
        ClassTimeConfig(2, "2", "0845", "0925"),
        ClassTimeConfig(3, "3", "0945", "1025"),
        ClassTimeConfig(4, "4", "1035", "1115"),
        ClassTimeConfig(5, "5", "1120", "1200"),
        ClassTimeConfig(6, "6", "1330", "1410"),
        ClassTimeConfig(7, "7", "1415", "1455"),
        ClassTimeConfig(8, "8", "1515", "1555"),
        ClassTimeConfig(9, "9", "1600", "1640"),
        ClassTimeConfig(10, "10", "1830", "1910"),
        ClassTimeConfig(11, "11", "1915", "1955"),
        ClassTimeConfig(12, "12", "2005", "2045"),
    )

    fun all(): List<ClassTimeConfig> = classTimes

    fun forSlot(slot: Int): ClassTimeConfig? = classTimes.firstOrNull { it.slotNumber == slot }

    fun startMinutes(slot: Int): Int = forSlot(slot)?.startTimeInMinutes ?: 0

    fun endMinutes(slot: Int): Int = forSlot(slot)?.endTimeInMinutes ?: 0

    /** 从 startSlot 起连续 duration 节的总时长（分钟） */
    fun durationMinutes(startSlot: Int, duration: Int): Int {
        val start = forSlot(startSlot) ?: return 0
        val end = forSlot(startSlot + duration - 1) ?: return 0
        return end.endTimeInMinutes - start.startTimeInMinutes
    }

    /** 节次时间范围，格式 "08:00-08:40" */
    fun timeRange(slot: Int): String = forSlot(slot)?.formatRange().orEmpty()

    /** 由分钟数反查最接近的节次（ICS 导入用） */
    fun nearestSlot(minutes: Int): Int {
        var best = 1
        var bestDelta = Int.MAX_VALUE
        for (item in classTimes) {
            val delta = kotlin.math.abs(item.startTimeInMinutes - minutes)
            if (delta < bestDelta) {
                bestDelta = delta
                best = item.slotNumber
            }
        }
        return best
    }
}
