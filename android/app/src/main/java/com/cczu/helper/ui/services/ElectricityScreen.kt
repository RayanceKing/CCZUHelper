package com.cczu.helper.ui.services

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.cczukit.getBuildings
import com.cczu.cczukit.getElectricityAreas
import com.cczu.cczukit.queryElectricity
import com.cczu.cczukit.models.Building
import com.cczu.cczukit.models.ElectricityArea
import com.cczu.helper.data.AccountState
import com.cczu.helper.data.readableMessage
import com.cczu.helper.di.AppContainer
import com.cczu.helper.ui.Routes
import com.cczu.helper.ui.components.DetailScaffold
import kotlinx.coroutines.launch

@Composable
fun ElectricityScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.account.collectAsStateWithLifecycle(initialValue = AccountState())
    val scope = rememberCoroutineScope()

    val areas = remember { container.session.app?.getElectricityAreas() ?: defaultAreas() }
    var area by remember { mutableStateOf(areas.firstOrNull()) }
    var buildings by remember { mutableStateOf<List<Building>>(emptyList()) }
    var building by remember { mutableStateOf<Building?>(null) }
    var room by remember { mutableStateOf("") }
    var result by remember { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }

    DetailScaffold(title = "电费查询", onBack = { navController.popBackStack() }) { padding ->
        if (!account.isLoggedIn) {
            com.cczu.helper.ui.services.RequireLogin { navController.navigate(Routes.LOGIN) }
            return@DetailScaffold
        }

        Column(modifier = padding.padding(16.dp)) {
            Picker(
                label = "校区",
                value = area?.areaname.orEmpty(),
                options = areas.map { it.areaname },
                onSelect = { name ->
                    area = areas.firstOrNull { it.areaname == name }
                    buildings = emptyList()
                    building = null
                    area?.let {
                        scope.launch {
                            runCatching { container.session.require().getBuildings(it) }
                                .onSuccess { buildings = it }
                                .onFailure { message = it.readableMessage() }
                        }
                    }
                },
            )

            Picker(
                label = "楼栋",
                value = building?.building.orEmpty(),
                options = buildings.map { it.building },
                onSelect = { name -> building = buildings.firstOrNull { it.building == name } },
            )

            OutlinedTextField(
                value = room,
                onValueChange = { room = it },
                label = { Text("房间号") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )

            Button(
                onClick = {
                    val currentArea = area ?: return@Button
                    val currentBuilding = building ?: return@Button
                    if (room.isBlank()) return@Button
                    loading = true
                    scope.launch {
                        runCatching {
                            container.session.require().queryElectricity(
                                area = currentArea,
                                building = currentBuilding,
                                roomId = room.trim(),
                            )
                        }.onSuccess {
                            result = it.errmsg
                            message = null
                        }.onFailure {
                            message = it.readableMessage()
                        }
                        loading = false
                    }
                },
                enabled = !loading && area != null && building != null && room.isNotBlank(),
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) {
                Text(if (loading) "查询中…" else "查询电费")
            }

            message?.let {
                Text(
                    text = it,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }

            if (result.isNotBlank()) {
                Text(
                    text = result,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 16.dp),
                )
            }
        }
    }
}

@Composable
private fun Picker(
    label: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(text = label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(if (value.isBlank()) "请选择" else value)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        onSelect(option)
                        expanded = false
                    },
                )
            }
        }
    }
}

/** 教务库未初始化时的兜底校区（与 iOS 版预置一致） */
private fun defaultAreas(): List<ElectricityArea> = listOf(
    ElectricityArea(area = "1", areaname = "武进校区", aid = "1"),
    ElectricityArea(area = "2", areaname = "白云校区", aid = "2"),
)
