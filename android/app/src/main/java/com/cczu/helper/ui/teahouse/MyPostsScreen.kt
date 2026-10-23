package com.cczu.helper.ui.teahouse

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.cczu.helper.data.TeahouseAccount
import com.cczu.helper.di.AppContainer
import com.cczu.helper.supabase.PostDto
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyPostsScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.teahouseAccount.collectAsStateWithLifecycle(initialValue = TeahouseAccount())
    val scope = rememberCoroutineScope()
    var posts by remember { mutableStateOf<List<PostDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    val load: suspend () -> Unit = {
        loading = true
        error = null
        runCatching { container.teahouse.fetchUserPosts(account.userId) }
            .onSuccess { posts = it }
            .onFailure { error = it.message ?: "加载失败" }
        loading = false
    }

    LaunchedEffect(account.userId) { load() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("我的帖子") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
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
                posts.isEmpty() -> Text(
                    text = "还没有发布过帖子",
                    modifier = Modifier.align(Alignment.Center),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(posts, key = { it.id ?: it.hashCode().toString() }) { post ->
                        PostCard(post = post, onClick = {
                            post.id?.let { navController.navigate(Routes.postDetail(it)) }
                        })
                    }
                    item { Box(modifier = Modifier.fillMaxWidth().padding(24.dp)) }
                }
            }
        }
    }
}
