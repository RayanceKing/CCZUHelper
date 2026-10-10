package com.cczu.helper.supabase

import com.google.gson.annotations.SerializedName

data class AuthUser(
    val id: String? = null,
    val email: String? = null,
)

data class AuthResponse(
    @SerializedName("access_token") val accessTokenValue: String? = null,
    @SerializedName("refresh_token") val refreshToken: String? = null,
    @SerializedName("expires_in") val expiresIn: Int? = null,
    val user: AuthUser? = null,
) {
    val access_token: String? get() = accessTokenValue
}

data class ProfilePreview(
    val id: String? = null,
    val username: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    @SerializedName("is_privilege") val isPrivilege: Boolean? = null,
)

data class ProfileDto(
    val id: String? = null,
    @SerializedName("real_name") val realName: String? = null,
    @SerializedName("student_id") val studentId: String? = null,
    @SerializedName("class_name") val className: String? = null,
    @SerializedName("college_name") val collegeName: String? = null,
    val grade: Int? = null,
    val username: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    @SerializedName("is_privilege") val isPrivilege: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
)

data class PostDto(
    val id: String? = null,
    @SerializedName("user_id") val userId: String? = null,
    @SerializedName("category_id") val categoryId: Int? = null,
    val title: String? = null,
    val content: String? = null,
    @SerializedName("image_urls") val imageUrls: String? = null,
    val price: Double? = null,
    @SerializedName("is_anonymous") val isAnonymous: Boolean? = null,
    val status: String? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    @SerializedName("like_count") val likeCount: Int? = null,
    @SerializedName("comment_count") val commentCount: Int? = null,
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

data class CommentDto(
    val id: String? = null,
    @SerializedName("post_id") val postId: String? = null,
    @SerializedName("user_id") val userId: String? = null,
    @SerializedName("parent_comment_id") val parentCommentId: String? = null,
    val content: String? = null,
    @SerializedName("is_anonymous") val isAnonymous: Boolean? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    val profile: ProfilePreview? = null,
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
