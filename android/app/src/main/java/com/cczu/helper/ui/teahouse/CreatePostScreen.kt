package com.cczu.helper.ui.teahouse

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.cczu.helper.data.TeahouseAccount
import com.cczu.helper.di.AppContainer
import com.cczu.helper.supabase.POST_CATEGORIES
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreatePostScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.teahouseAccount.collectAsStateWithLifecycle(initialValue = TeahouseAccount())
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    var title by remember { mutableStateOf("") }
    var content by remember { mutableStateOf("") }
    var price by remember { mutableStateOf("") }
    var anonymous by remember { mutableStateOf(false) }
    var categoryIndex by remember { mutableStateOf(0) }
    var expanded by remember { mutableStateOf(false) }
    var images by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var uploading by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) message = null else message = "需要相册权限才能选图" }

    val imageLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetMultipleContents()
    ) { uris -> images = (images + uris).take(6) }

    fun pickImages() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED) {
            imageLauncher.launch("image/*")
        } else {
            permissionLauncher.launch(permission)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("发布帖子") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    TextButton(onClick = {
                        if (title.isBlank() || content.isBlank() || uploading) return@TextButton
                        uploading = true
                        scope.launch {
                            runCatching {
                                val urls = images.mapNotNull { uri ->
                                    runCatching {
                                        val bytes = readBytes(context, uri)
                                        val name = uri.lastPathSegment ?: "image.jpg"
                                        container.teahouse.uploadImage(bytes, name, "image/jpeg")
                                    }.getOrNull()
                                }
                                container.teahouse.createPost(
                                    userId = account.userId,
                                    title = title.trim(),
                                    content = content.trim(),
                                    categoryId = POST_CATEGORIES[categoryIndex].id,
                                    imageUrls = urls,
                                    price = price.toDoubleOrNull(),
                                    isAnonymous = anonymous,
                                )
                            }.onSuccess {
                                uploading = false
                                navController.popBackStack()
                            }.onFailure {
                                uploading = false
                                message = "发布失败：${it.message ?: it.javaClass.simpleName}"
                            }
                        }
                    }) { Text("发布") }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize(),
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("标题") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = content,
                onValueChange = { content = it },
                label = { Text("正文") },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp)
                    .weight(1f),
                minLines = 6,
            )

            Row(
                modifier = Modifier.padding(top = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("分类", modifier = Modifier.padding(end = 8.dp))
                Box {
                    TextButton(onClick = { expanded = true }) {
                        Text(POST_CATEGORIES[categoryIndex].name)
                    }
                    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                        POST_CATEGORIES.forEachIndexed { index, category ->
                            DropdownMenuItem(
                                text = { Text(category.name) },
                                onClick = { categoryIndex = index; expanded = false },
                            )
                        }
                    }
                }
            }

            if (POST_CATEGORIES[categoryIndex].id == 3) {
                OutlinedTextField(
                    value = price,
                    onValueChange = { price = it },
                    label = { Text("价格") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("匿名发布")
                Switch(checked = anonymous, onCheckedChange = { anonymous = it })
            }

            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Button(onClick = { pickImages() }) { Text("选择图片") }
                if (uploading) CircularProgressIndicator(modifier = Modifier.size(20.dp))
                images.forEach { uri ->
                    AsyncImage(
                        model = uri,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(8.dp)),
                    )
                }
            }

            message?.let {
                Text(
                    text = it,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
        }
    }
}

private fun readBytes(context: Context, uri: Uri): ByteArray =
    context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
