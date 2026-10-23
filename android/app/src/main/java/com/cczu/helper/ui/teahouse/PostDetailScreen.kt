package com.cczu.helper.ui.teahouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.TeahouseAccount
import com.cczu.helper.di.AppContainer
import com.cczu.helper.supabase.CommentDto
import com.cczu.helper.supabase.PostDto
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostDetailScreen(container: AppContainer, navController: NavController, postId: String) {
    val account by container.settings.teahouseAccount.collectAsStateWithLifecycle(initialValue = TeahouseAccount())
    val scope = rememberCoroutineScope()

    var post by remember { mutableStateOf<PostDto?>(null) }
    var comments by remember { mutableStateOf<List<CommentDto>>(emptyList()) }
    var liked by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var draft by remember { mutableStateOf("") }

    val userId = account.userId

    val load: suspend () -> Unit = {
        loading = true
        error = null
        runCatching {
            val detail = container.teahouse.fetchPost(postId)
            val list = container.teahouse.fetchComments(postId)
            val isLiked = if (userId.isBlank()) false else container.teahouse.isLiked(postId, userId)
            Triple(detail, list, isLiked)
        }.onSuccess { (detail, list, isLiked) ->
            post = detail
            comments = list
            liked = isLiked
        }.onFailure { error = it.message ?: "加载失败" }
        loading = false
    }

    LaunchedEffect(postId) { load() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("帖子详情") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text("说点什么…") },
                    modifier = Modifier.weight(1f),
                    maxLines = 3,
                )
                TextButton(onClick = {
                    if (draft.isBlank() || userId.isBlank()) return@TextButton
                    scope.launch {
                        runCatching {
                            container.teahouse.addComment(postId, userId, draft.trim())
                        }.onSuccess {
                            draft = ""
                            load()
                        }
                    }
                }) { Text("发送") }
            }
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                loading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                error != null -> Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(text = error ?: "", color = MaterialTheme.colorScheme.error)
                    Button(onClick = { scope.launch { load() } }) { Text("重试") }
                }
                else -> {
                    val current = post
                    if (current == null) {
                        Text("帖子不存在", modifier = Modifier.align(Alignment.Center))
                    } else {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            item {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    Text(text = current.title.orEmpty(), style = MaterialTheme.typography.headlineSmall)
                                    Text(
                                        text = current.profile?.username?.takeIf { it.isNotBlank() } ?: "匿名",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                    Text(
                                        text = current.content.orEmpty(),
                                        modifier = Modifier.padding(top = 12.dp),
                                        style = MaterialTheme.typography.bodyLarge,
                                    )
                                    current.price?.let {
                                        Text(
                                            text = "价格：¥${it}",
                                            modifier = Modifier.padding(top = 8.dp),
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                    }
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        IconButton(onClick = {
                                            if (userId.isBlank()) {
                                                navController.navigate(Routes.TEAHOUSE_LOGIN)
                                                return@IconButton
                                            }
                                            scope.launch {
                                                runCatching { container.teahouse.toggleLike(postId, userId) }
                                                    .onSuccess { liked = it; load() }
                                            }
                                        }) {
                                            Icon(
                                                if (liked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                                                contentDescription = "点赞",
                                                tint = if (liked) MaterialTheme.colorScheme.primary
                                                else MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                        Text(text = "${current.likeCount ?: 0}")
                                        if (current.userId == userId && userId.isNotBlank()) {
                                            TextButton(onClick = {
                                                scope.launch {
                                                    runCatching { container.teahouse.deletePost(postId) }
                                                        .onSuccess { navController.popBackStack() }
                                                }
                                            }) { Text("删除帖子") }
                                        }
                                    }
                                }
                            }
                            item {
                                Text(
                                    text = "评论 ${comments.size}",
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                                    style = MaterialTheme.typography.titleSmall,
                                )
                            }
                            items(comments, key = { it.id ?: it.hashCode().toString() }) { comment ->
                                Surface(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 12.dp, vertical = 4.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    tonalElevation = 0.5.dp,
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(
                                            text = comment.profile?.username?.takeIf { it.isNotBlank() } ?: "匿名",
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                        Text(
                                            text = comment.content.orEmpty(),
                                            modifier = Modifier.padding(top = 4.dp),
                                        )
                                    }
                                }
                            }
                            item {
                                Box(modifier = Modifier.fillMaxWidth().padding(24.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}
