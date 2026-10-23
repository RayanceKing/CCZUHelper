package com.cczu.helper.supabase

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ProfilePreview(
    val id: String? = null,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_privilege") val isPrivilege: Boolean? = null,
)

@Serializable
data class ProfileDto(
    val id: String? = null,
    @SerialName("real_name") val realName: String? = null,
    @SerialName("student_id") val studentId: String? = null,
    @SerialName("class_name") val className: String? = null,
    @SerialName("college_name") val collegeName: String? = null,
    val grade: Int? = null,
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_privilege") val isPrivilege: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class PostDto(
    val id: String? = null,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("category_id") val categoryId: Int? = null,
    val title: String? = null,
    val content: String? = null,
    @SerialName("image_urls") val imageUrls: String? = null,
    val price: Double? = null,
    @SerialName("is_anonymous") val isAnonymous: Boolean? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("like_count") val likeCount: Int? = null,
    @SerialName("comment_count") val commentCount: Int? = null,
    val profile: ProfilePreview? = null,
) {
    /** image_urls 可能是 JSON 数组字符串，也可能是单个 URL */
    val imageUrlList: List<String>
        get() {
            val raw = imageUrls?.trim().orEmpty()
            if (raw.isEmpty() || raw == "null") return emptyList()
            if (raw.startsWith("[")) {
                return raw.trim('[', ']')
                    .split(",")
                    .map { it.trim().trim('"') }
                    .filter { it.isNotEmpty() }
            }
            return listOf(raw)
        }
}

@Serializable
data class CommentDto(
    val id: String? = null,
    @SerialName("post_id") val postId: String? = null,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("parent_comment_id") val parentCommentId: String? = null,
    val content: String? = null,
    @SerialName("is_anonymous") val isAnonymous: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
    val profile: ProfilePreview? = null,
)

// ---- 写入用的请求体（kotlinx.serialization） ----

@Serializable
data class PostInsert(
    @SerialName("user_id") val userId: String,
    @SerialName("category_id") val categoryId: Int,
    val title: String,
    val content: String,
    @SerialName("image_urls") val imageUrls: String?,
    val price: Double? = null,
    @SerialName("is_anonymous") val isAnonymous: Boolean,
    val status: String = "available",
)

@Serializable
data class CommentInsert(
    @SerialName("post_id") val postId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("parent_comment_id") val parentCommentId: String? = null,
    val content: String,
    @SerialName("is_anonymous") val isAnonymous: Boolean = false,
)

@Serializable
data class LikeInsert(
    @SerialName("post_id") val postId: String,
    @SerialName("user_id") val userId: String,
)

@Serializable
data class LikeRow(
    val id: String? = null,
)

@Serializable
data class ProfileUpdate(
    val username: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

/** 帖子分类（与 iOS 版一致：学习 1 / 生活 2 / 二手 3 / 表白 4 / 失物招领 5） */
data class PostCategory(val id: Int, val name: String)

val POST_CATEGORIES = listOf(
    PostCategory(1, "学习"),
    PostCategory(2, "生活"),
    PostCategory(3, "二手"),
    PostCategory(4, "表白"),
    PostCategory(5, "失物招领"),
)
