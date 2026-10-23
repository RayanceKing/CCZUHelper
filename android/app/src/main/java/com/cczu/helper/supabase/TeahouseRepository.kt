package com.cczu.helper.supabase

import com.cczu.helper.data.SettingsRepository
import com.cczu.helper.data.TeahouseAccount
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Count
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.IOException

/** 茶楼数据仓库：负责会话保持与业务调用（基于官方 supabase-kt 客户端） */
class TeahouseRepository(
    private val supabase: SupabaseClient,
    private val settings: SettingsRepository,
) {

    suspend fun restoreSession() {
        val account = settings.currentTeahouseAccount()
        val json = account.sessionJson
        if (json.isNotBlank()) {
            try {
                val session = TeahouseSupabase.sessionJson.decodeFromString<UserSession>(json)
                supabase.auth.importSession(session)
            } catch (_: Exception) {
                // 会话已失效，忽略，等待用户重新登录
            }
        }
    }

    fun isSignedIn(): Boolean = supabase.auth.currentSessionOrNull() != null

    suspend fun currentUserId(): String {
        val stored = settings.currentTeahouseAccount()
        return supabase.auth.currentUserOrNull()?.id ?: stored.userId
    }

    suspend fun signIn(email: String, password: String) {
        supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        val session = supabase.auth.currentSessionOrNull()
            ?: throw IOException("登录失败：未获取到会话")
        settings.saveTeahouseAccount(
            TeahouseAccount(
                email = email,
                password = password,
                userId = session.user?.id.orEmpty(),
                accessToken = session.accessToken,
                refreshToken = session.refreshToken,
                displayName = session.user?.email ?: email,
                sessionJson = TeahouseSupabase.sessionJson.encodeToString(session),
            )
        )
    }

    suspend fun signUp(email: String, password: String) {
        supabase.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        val session = supabase.auth.currentSessionOrNull()
        settings.saveTeahouseAccount(
            TeahouseAccount(
                email = email,
                password = password,
                userId = session?.user?.id.orEmpty(),
                accessToken = session?.accessToken.orEmpty(),
                refreshToken = session?.refreshToken.orEmpty(),
                displayName = session?.user?.email ?: email,
                sessionJson = if (session != null) TeahouseSupabase.sessionJson.encodeToString(session) else "",
            )
        )
    }

    suspend fun signOut() {
        try {
            supabase.auth.signOut()
        } catch (_: Exception) {
            // 即使服务端退出失败，本地也清理
        }
        settings.saveTeahouseAccount(TeahouseAccount())
    }

    suspend fun fetchPosts(): List<PostDto> =
        supabase.from("posts_with_metadata")
            .select(Columns.raw("*, profile:profiles!user_id(id, username, avatar_url)")) {
                order("created_at", Order.DESCENDING)
            }
            .decodeList<PostDto>()
            .filter { it.status == "available" || it.status == "sold" }

    suspend fun fetchPost(id: String): PostDto? =
        supabase.from("posts_with_metadata")
            .select(Columns.raw("*, profile:profiles!user_id(id, username, avatar_url)")) {
                filter { eq("id", id) }
            }
            .decodeSingleOrNull<PostDto>()

    suspend fun fetchUserPosts(userId: String): List<PostDto> =
        supabase.from("posts_with_metadata")
            .select(Columns.raw("*, profile:profiles!user_id(id, username, avatar_url)")) {
                filter { eq("user_id", userId) }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<PostDto>()

    suspend fun createPost(
        userId: String,
        title: String,
        content: String,
        categoryId: Int,
        imageUrls: List<String>,
        price: Double?,
        isAnonymous: Boolean,
    ) {
        val imageField = if (imageUrls.isEmpty()) null else Json.encodeToString(imageUrls)
        val payload = PostInsert(
            userId = userId,
            categoryId = categoryId,
            title = title,
            content = content,
            imageUrls = imageField,
            price = price,
            isAnonymous = isAnonymous,
            status = "available",
        )
        supabase.from("posts").insert(payload) { select() }
    }

    suspend fun deletePost(postId: String) {
        try { supabase.from("likes").delete { filter { eq("post_id", postId) } } } catch (_: Exception) { }
        try { supabase.from("comments").delete { filter { eq("post_id", postId) } } } catch (_: Exception) { }
        supabase.from("posts").delete { filter { eq("id", postId) } }
    }

    suspend fun fetchComments(postId: String): List<CommentDto> =
        supabase.from("comments")
            .select(Columns.raw("*, profile:profiles!user_id(username, avatar_url)")) {
                filter { eq("post_id", postId) }
                order("created_at", Order.ASCENDING)
            }
            .decodeList<CommentDto>()

    suspend fun addComment(
        postId: String,
        userId: String,
        content: String,
        parentCommentId: String? = null,
        isAnonymous: Boolean = false,
    ) {
        val payload = CommentInsert(
            postId = postId,
            userId = userId,
            parentCommentId = parentCommentId,
            content = content,
            isAnonymous = isAnonymous,
        )
        supabase.from("comments").insert(payload) { select() }
    }

    suspend fun isLiked(postId: String, userId: String): Boolean {
        val result = supabase.from("likes")
            .select {
                count(Count.EXACT)
                filter { eq("post_id", postId); eq("user_id", userId) }
            }
        return (result.countOrNull() ?: 0L) > 0L
    }

    suspend fun toggleLike(postId: String, userId: String): Boolean {
        return if (isLiked(postId, userId)) {
            supabase.from("likes").delete { filter { eq("post_id", postId); eq("user_id", userId) } }
            false
        } else {
            supabase.from("likes").insert(LikeInsert(postId, userId)) { select() }
            true
        }
    }

    suspend fun fetchProfile(userId: String): ProfileDto? =
        supabase.from("profiles")
            .select(
                Columns.raw(
                    "id, real_name, student_id, class_name, college_name, " +
                        "grade, username, avatar_url, is_privilege, created_at"
                )
            ) {
                filter { eq("id", userId) }
            }
            .decodeSingleOrNull<ProfileDto>()

    suspend fun updateProfile(userId: String, username: String, avatarUrl: String?) {
        val payload = ProfileUpdate(username = username, avatarUrl = avatarUrl)
        supabase.from("profiles").update(payload) {
            filter { eq("id", userId) }
            select()
        }
    }

    suspend fun uploadImage(bytes: ByteArray, fileName: String, mimeType: String): String =
        TeahouseSupabase.uploadImage(bytes, fileName, mimeType)

    suspend fun registerStudentProfile(
        realName: String,
        studentId: String,
        className: String,
        grade: Int,
        collegeName: String,
        username: String?,
        avatarUrl: String?,
    ) {
        val params = buildJsonObject {
            put("p_real_name", realName)
            put("p_student_id", studentId)
            put("p_class_name", className)
            put("p_grade", grade)
            put("p_college_name", collegeName)
            if (username != null) put("p_username", username)
            if (avatarUrl != null) put("p_avatar_url", avatarUrl)
        }
        supabase.postgrest.rpc("register_student_profile", params)
    }
}
