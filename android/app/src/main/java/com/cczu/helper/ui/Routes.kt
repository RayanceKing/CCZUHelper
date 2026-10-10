package com.cczu.helper.ui

/** 全部导航路由 */
object Routes {
    const val SCHEDULE = "schedule"
    const val SERVICES = "services"
    const val TEAHOUSE = "teahouse"
    const val PROFILE = "profile"

    const val LOGIN = "login"
    const val MANAGE_SCHEDULES = "manage_schedules"

    const val GRADE = "grade"
    const val GPA = "gpa"
    const val EXAM = "exam"
    const val EVALUATION = "evaluation"
    const val SELECTION = "selection"
    const val ELECTRICITY = "electricity"
    const val TRAINING_PLAN = "training_plan"

    const val SETTINGS = "settings"
    const val USER_INFO = "user_info"

    const val TEAHOUSE_LOGIN = "teahouse_login"
    const val CREATE_POST = "create_post"
    const val MY_POSTS = "my_posts"
    const val POST_DETAIL = "post/{postId}"

    fun postDetail(postId: String): String = "post/$postId"
}

val TOP_LEVEL_ROUTES = listOf(Routes.SCHEDULE, Routes.SERVICES, Routes.TEAHOUSE, Routes.PROFILE)
