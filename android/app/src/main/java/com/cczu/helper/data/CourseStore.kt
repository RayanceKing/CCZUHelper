package com.cczu.helper.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.util.UUID

/** 课表与课程的本地存储（JSON 文件，对应 Swift 版 SwiftData 持久化） */
class CourseStore(context: Context) {

    private val gson = Gson()
    private val file = File(context.filesDir, "schedules.json")
    private val mutex = Mutex()

    private val _snapshot = MutableStateFlow(readFromDisk())
    val snapshot: StateFlow<StoreSnapshot> = _snapshot

    private fun readFromDisk(): StoreSnapshot {
        if (!file.exists()) return StoreSnapshot()
        return runCatching {
            val type = object : TypeToken<StoreSnapshot>() {}
            gson.fromJson(file.readText(), type.type) ?: StoreSnapshot()
        }.getOrDefault(StoreSnapshot())
    }

    private suspend fun persist(snapshot: StoreSnapshot) {
        _snapshot.value = snapshot
        mutex.withLock {
            runCatching { file.writeText(gson.toJson(snapshot)) }
        }
    }

    suspend fun addSchedule(name: String, termName: String, courses: List<CourseEntity>): ScheduleEntity {
        val schedule = ScheduleEntity(
            id = UUID.randomUUID().toString(),
            name = name,
            termName = termName,
            createdAt = System.currentTimeMillis(),
            isActive = true,
        )
        val current = _snapshot.value
        val schedules = current.schedules.map { it.copy(isActive = false) } + schedule
        val withIds = courses.map { it.copy(id = UUID.randomUUID().toString(), scheduleId = schedule.id) }
        persist(StoreSnapshot(schedules, current.courses + withIds))
        return schedule
    }

    suspend fun replaceCourses(scheduleId: String, courses: List<CourseEntity>) {
        val current = _snapshot.value
        val others = current.courses.filter { it.scheduleId != scheduleId }
        val withIds = courses.map {
            it.copy(
                id = if (it.id.isBlank()) UUID.randomUUID().toString() else it.id,
                scheduleId = scheduleId,
            )
        }
        persist(StoreSnapshot(current.schedules, others + withIds))
    }

    suspend fun setActiveSchedule(scheduleId: String) {
        val current = _snapshot.value
        persist(
            StoreSnapshot(
                current.schedules.map { it.copy(isActive = it.id == scheduleId) },
                current.courses,
            )
        )
    }

    suspend fun renameSchedule(scheduleId: String, name: String) {
        val current = _snapshot.value
        persist(
            StoreSnapshot(
                current.schedules.map { if (it.id == scheduleId) it.copy(name = name) else it },
                current.courses,
            )
        )
    }

    suspend fun deleteSchedule(scheduleId: String) {
        val current = _snapshot.value
        val schedules = current.schedules.filter { it.id != scheduleId }
        val courses = current.courses.filter { it.scheduleId != scheduleId }
        val next = if (schedules.isNotEmpty() && schedules.none { it.isActive }) {
            schedules.mapIndexed { index, item -> item.copy(isActive = index == 0) }
        } else {
            schedules
        }
        persist(StoreSnapshot(next, courses))
    }

    fun activeSchedule(): ScheduleEntity? {
        val schedules = _snapshot.value.schedules
        return schedules.firstOrNull { it.isActive } ?: schedules.firstOrNull()
    }

    fun coursesFor(scheduleId: String): List<CourseEntity> =
        _snapshot.value.courses.filter { it.scheduleId == scheduleId }
}
