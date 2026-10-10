package com.cczu.helper.supabase

import com.cczu.helper.data.SettingsRepository
import com.cczu.helper.data.TeahouseAccount
import com.google.gson.Gson

/** 茶楼数据仓库：负责会话保持与业务调用 */
class TeahouseRepository(
    private val api: SupabaseApi,
    private val settings: SettingsRepository,
) {

    suspend fun restoreSession() {
        val account = settings.currentTeahouseAccount()
        if (account.accessToken.isNotBlank()) {
            api.accessToken = account.accessToken
        }
    }

    fun isSignedIn(): Boolean = api.accessToken.isNullOrBlank().not()

    suspend fun signIn(email: String, password: String) {
        val response = api.signIn(email, password)
        settings.saveTeahouseAccount(
            TeahouseAccount(
                email = email,
                password = password,
                userId = response.user?.id.orEmpty(),
                accessToken = response.access_token.orEmpty(),
                refreshToken = response.refreshToken.orEmpty(),
            )
        )
    }

    suspend fun signUp(email: String, password: String) {
        val response = api.signUp(email, password)
        settings.saveTeahouseAccount(
            TeahouseAccount(
                email = email,
                password = password,
                userId = response.user?.id.orEmpty(),
                accessToken = response.access_token.orEmpty(),
                refreshToken = response.refreshToken.orEmpty(),
            )
        )
    }

    suspend fun signOut() {
        api.signOut()
        settings.saveTeahouseAccount(TeahouseAccount())
    }

    suspend fun currentUserId(): String {
        val stored = settings.currentTeahouseAccount()
        return stored.userId.ifBlank { api.accessToken?.let { "" } ?: "" }
    }

    suspend fun fetchPosts(): List<PostDto> = api.fetchPosts()

    suspend fun fetchPost(id: String): PostDto? = api.fetchPost(id)

    suspend fun fetchUserPosts(userId: String): List<PostDto> = api.fetchUserPosts(userId)

    suspend fun createPost(
        userId: String,
        title: String,
        content: String,
        categoryId: Int,
        imageUrls: List<String>,
        price: Double?,
        isAnonymous: Boolean,
    ) {
        val imageField = if (imageUrls.isEmpty()) null else Gson().toJson(imageUrls)
        api.createPost(
            mapOf(
                "user_id" to userId,
                "category_id" to categoryId,
                "title" to title,
                "content" to content,
                "image_urls" to imageField,
                "price" to price,
                "is_anonymous" to isAnonymous,
                "status" to "available",
            )
        )
    }

    suspend fun deletePost(postId: String) = api.deletePost(postId)

    suspend fun fetchComments(postId: String): List<CommentDto> = api.fetchComments(postId)

    suspend fun addComment(
        postId: String,
        userId: String,
        content: String,
        parentCommentId: String? = null,
        isAnonymous: Boolean = false,
    ) {
        api.addComment(
            mapOf(
                "post_id" to postId,
                "user_id" to userId,
                "parent_comment_id" to parentCommentId,
                "content" to content,
                "is_anonymous" to isAnonymous,
            )
        )
    }

    suspend fun isLiked(postId: String, userId: String): Boolean = api.isLiked(postId, userId)

    suspend fun toggleLike(postId: String, userId: String): Boolean {
        return if (api.isLiked(postId, userId)) {
            api.unlike(postId, userId)
            false
        } else {
            api.like(postId, userId)
            true
        }
    }

    suspend fun fetchProfile(userId: String): ProfileDto? = api.fetchProfile(userId)

    suspend fun updateProfile(userId: String, username: String, avatarUrl: String?) {
        api.updateProfile(userId, mapOf("username" to username, "avatar_url" to avatarUrl))
    }

    suspend fun uploadImage(bytes: ByteArray, fileName: String, mimeType: String): String =
        api.uploadImage(bytes, fileName, mimeType)

    suspend fun registerStudentProfile(
        realName: String,
        studentId: String,
        className: String,
        grade: Int,
        collegeName: String,
        username: String?,
        avatarUrl: String?,
    ) {
        api.registerStudentProfile(
            mapOf(
                "p_real_name" to realName,
                "p_student_id" to studentId,
                "p_class_name" to className,
                "p_grade" to grade,
                "p_college_name" to collegeName,
                "p_username" to username,
                "p_avatar_url" to avatarUrl,
            )
        )
    }
}
