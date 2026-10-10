package com.cczu.helper.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Coffee
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.login.LoginScreen
import com.cczu.helper.ui.schedule.ManageSchedulesScreen
import com.cczu.helper.ui.schedule.ScheduleScreen
import com.cczu.helper.ui.services.CourseSelectionScreen
import com.cczu.helper.ui.services.ElectricityScreen
import com.cczu.helper.ui.services.EvaluationScreen
import com.cczu.helper.ui.services.ExamScreen
import com.cczu.helper.ui.services.GpaScreen
import com.cczu.helper.ui.services.GradeScreen
import com.cczu.helper.ui.services.ServicesScreen
import com.cczu.helper.ui.services.TrainingPlanScreen
import com.cczu.helper.ui.settings.SettingsScreen
import com.cczu.helper.ui.teahouse.CreatePostScreen
import com.cczu.helper.ui.teahouse.MyPostsScreen
import com.cczu.helper.ui.teahouse.PostDetailScreen
import com.cczu.helper.ui.teahouse.TeahouseLoginScreen
import com.cczu.helper.ui.teahouse.TeahouseScreen
import com.cczu.helper.ui.user.ProfileScreen
import com.cczu.helper.ui.user.UserInfoScreen

@Composable
fun AppNav(container: AppContainer, onFinish: () -> Unit) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            if (currentRoute in TOP_LEVEL_ROUTES) {
                NavigationBar {
                    val items = listOf(
                        Triple(Routes.SCHEDULE, "课程表", Icons.Filled.CalendarMonth),
                        Triple(Routes.SERVICES, "服务", Icons.Filled.GridView),
                        Triple(Routes.TEAHOUSE, "茶楼", Icons.Filled.Coffee),
                        Triple(Routes.PROFILE, "我的", Icons.Filled.Person),
                    )
                    items.forEach { (route, label, icon) ->
                        val selected = backStackEntry?.destination?.hierarchy?.any { it.route == route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(icon, contentDescription = label) },
                            label = { Text(label) },
                        )
                    }
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Routes.SCHEDULE,
            modifier = Modifier.padding(padding),
        ) {
            composable(Routes.SCHEDULE) { ScheduleScreen(container, navController) }
            composable(Routes.SERVICES) { ServicesScreen(container, navController) }
            composable(Routes.TEAHOUSE) { TeahouseScreen(container, navController) }
            composable(Routes.PROFILE) { ProfileScreen(container, navController, onFinish) }

            composable(Routes.LOGIN) { LoginScreen(container, navController) }
            composable(Routes.MANAGE_SCHEDULES) { ManageSchedulesScreen(container, navController) }

            composable(Routes.GRADE) { GradeScreen(container, navController) }
            composable(Routes.GPA) { GpaScreen(container, navController) }
            composable(Routes.EXAM) { ExamScreen(container, navController) }
            composable(Routes.EVALUATION) { EvaluationScreen(container, navController) }
            composable(Routes.SELECTION) { CourseSelectionScreen(container, navController) }
            composable(Routes.ELECTRICITY) { ElectricityScreen(container, navController) }
            composable(Routes.TRAINING_PLAN) { TrainingPlanScreen(container, navController) }

            composable(Routes.SETTINGS) { SettingsScreen(container, navController) }
            composable(Routes.USER_INFO) { UserInfoScreen(container, navController) }

            composable(Routes.TEAHOUSE_LOGIN) { TeahouseLoginScreen(container, navController) }
            composable(Routes.CREATE_POST) { CreatePostScreen(container, navController) }
            composable(Routes.MY_POSTS) { MyPostsScreen(container, navController) }
            composable(Routes.POST_DETAIL) { entry ->
                val postId = entry.arguments?.getString("postId").orEmpty()
                PostDetailScreen(container, navController, postId)
            }
        }
    }
}
