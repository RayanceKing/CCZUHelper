package com.cczu.helper.ui.teahouse

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.ModeComment
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.cczu.helper.data.TeahouseAccount
import com.cczu.helper.di.AppContainer
import com.cczu.helper.supabase.PostDto
import com.cczu.helper.ui.Routes
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TeahouseScreen(container: AppContainer, navController: NavController) {
    val account by container.settings.teahouseAccount.collectAsStateWithLifecycle(initialValue = TeahouseAccount())
    val scope = rememberCoroutineScope()

    var posts by remember { mutableStateOf<List<PostDto>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var keyword by remember { mutableStateOf("") }

    val load: suspend () -> Unit = {
        loading = true
        error = null
        runCatching { container.teahouse.fetchPosts() }
            .onSuccess { posts = it }
            .onFailure { error = it.message ?: "加载失败" }
        loading = false
    }

    LaunchedEffect(Unit) {
        container.teahouse.restoreSession()
        load()
    }

    val visible = remember(posts, keyword) {
        if (keyword.isBlank()) posts
        else posts.filter {
            it.title.orEmpty().contains(keyword, ignoreCase = true) ||
                it.content.orEmpty().contains(keyword, ignoreCase = true) ||
                it.profile?.username.orEmpty().contains(keyword, ignoreCase = true)
        }
    }

    val signedIn = account.accessToken.isNotBlank()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("茶楼") },
                actions = {
                    if (!signedIn) {
                        Button(onClick = { navController.navigate(Routes.TEAHOUSE_LOGIN) }) {
                            Text("登录")
                        }
                    } else {
                        Button(onClick = { navController.navigate(Routes.MY_POSTS) }) {
                            Text("我的帖子")
                        }
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = {
                if (signedIn) navController.navigate(Routes.CREATE_POST)
                else navController.navigate(Routes.TEAHOUSE_LOGIN)
            }) {
                Icon(Icons.Filled.Add, contentDescription = "发帖")
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            OutlinedTextField(
                value = keyword,
                onValueChange = { keyword = it },
                placeholder = { Text("搜索帖子") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )

            when {
                loading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                error != null -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(text = error ?: "", color = MaterialTheme.colorScheme.error)
                        Button(onClick = { scope.launch { load() } }) { Text("重试") }
                    }
                }
                visible.isEmpty() -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("暂无帖子", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(visible, key = { it.id ?: it.hashCode().toString() }) { post ->
                        PostCard(post = post, onClick = {
                            post.id?.let { navController.navigate(Routes.postDetail(it)) }
                        })
                    }
                }
            }
        }
    }
}

@Composable
fun PostCard(post: PostDto, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        shape = RoundedCornerShape(14.dp),
        tonalElevation = 1.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(14.dp),
        ) {
            Text(text = post.title.orEmpty(), style = MaterialTheme.typography.titleMedium)
            Text(
                text = post.content.orEmpty(),
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            val images = post.imageUrlList
            if (images.isNotEmpty()) {
                Row(
                    modifier = Modifier.padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    images.take(3).forEach { url ->
                        AsyncImage(
                            model = url,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(72.dp)
                                .clip(RoundedCornerShape(8.dp)),
                        )
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = post.profile?.username?.takeIf { it.isNotBlank() } ?: "匿名",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    Icons.Filled.Favorite,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(text = "${post.likeCount ?: 0}", fontSize = 12.sp, modifier = Modifier.padding(start = 2.dp))
                Icon(
                    Icons.Filled.ModeComment,
                    contentDescription = null,
                    modifier = Modifier
                        .padding(start = 12.dp)
                        .size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(text = "${post.commentCount ?: 0}", fontSize = 12.sp, modifier = Modifier.padding(start = 2.dp))
            }
        }
    }
}

@Composable
fun TeahouseEmptyHint(text: String) {
    Box(modifier = Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
