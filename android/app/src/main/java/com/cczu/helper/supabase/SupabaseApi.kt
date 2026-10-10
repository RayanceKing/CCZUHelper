package com.cczu.helper.supabase

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resumeWithException

/**
 * Supabase REST 客户端（PostgREST + GoTrue + Storage）
 * 直接基于 OkHttp + Gson，避免引入额外的 SDK 版本依赖。
 */
class SupabaseApi {

    companion object {
        const val BASE_URL = "https://udrykrwyvnvmavbrdnnm.supabase.co"
        const val ANON_KEY = "sb_publishable_5mGAY5LN0WGnIIGwG30dxQ_mY7TuV_4"
        const val IMAGE_HOST_URL = "https://img.scdn.io/api/v1.php"
    }

    private val gson = Gson()
    private val jsonMedia = "application/json".toMediaType()

    private val ok: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    @Volatile
    var accessToken: String? = null

    // MARK: - 基础请求

    private fun headers(): Map<String, String> {
        val token = accessToken?.takeIf { it.isNotBlank() } ?: ANON_KEY
        return mapOf(
            "apikey" to ANON_KEY,
            "Authorization" to "Bearer $token",
            "Accept" to "application/json",
        )
    }

    private fun buildUrl(path: String, query: Map<String, String>): okhttp3.HttpUrl {
        val builder = (BASE_URL + path).toHttpUrl().newBuilder()
        query.forEach { (key, value) -> builder.addQueryParameter(key, value) }
        return builder.build()
    }

    private suspend fun call(
        method: String,
        path: String,
        query: Map<String, String> = emptyMap(),
        jsonBody: Any? = null,
        prefer: String? = null,
        extraHeaders: Map<String, String> = emptyMap(),
    ): String {
        val body = jsonBody?.let { gson.toJson(it).toRequestBody(jsonMedia) }
        val request = Request.Builder()
            .url(buildUrl(path, query))
            .method(method, body ?: if (method == "GET") null else "".toRequestBody(null))
            .apply {
                headers().forEach { (k, v) -> header(k, v) }
                extraHeaders.forEach { (k, v) -> header(k, v) }
                if (jsonBody != null) header("Content-Type", "application/json")
                if (prefer != null) header("Prefer", prefer)
            }
            .build()

        val response = ok.newCall(request).await()
        return response.use {
            val text = it.body?.string().orEmpty()
            if (!it.isSuccessful) {
                throw IOException("Supabase ${it.code}: $text")
            }
            text
        }
    }

    private inline fun <reified T> parseList(text: String): List<T> {
        if (text.isBlank() || text == "[]" || text == "null") return emptyList()
        val type = object : TypeToken<List<T>>() {}.type
        return runCatching { gson.fromJson<List<T>>(text, type) }.getOrDefault(emptyList())
    }

    private inline fun <reified T> parseOne(text: String): T? {
        if (text.isBlank() || text == "null") return null
        val list = parseList<T>(text)
        return list.firstOrNull()
    }

    // MARK: - Auth

    suspend fun signIn(email: String, password: String): AuthResponse {
        val text = call(
            "POST", "/auth/v1/token",
            query = mapOf("grant_type" to "password"),
            jsonBody = mapOf("email" to email, "password" to password),
        )
        val result = gson.fromJson(text, AuthResponse::class.java)
            ?: throw IOException("登录响应解析失败")
        accessToken = result.access_token
        return result
    }

    suspend fun signUp(email: String, password: String): AuthResponse {
        val text = call(
            "POST", "/auth/v1/signup",
            jsonBody = mapOf("email" to email, "password" to password),
        )
        val result = gson.fromJson(text, AuthResponse::class.java)
            ?: throw IOException("注册响应解析失败")
        accessToken = result.access_token ?: accessToken
        return result
    }

    suspend fun signOut() {
        runCatching { call("POST", "/auth/v1/logout") }
        accessToken = null
    }

    // MARK: - Profiles

    suspend fun fetchProfile(userId: String): ProfileDto? =
        parseOne(call("GET", "/rest/v1/profiles", query = mapOf("id" to "eq.$userId", "select" to "*")))

    suspend fun upsertProfile(profile: Map<String, Any?>): ProfileDto? =
        parseOne(
            call(
                "POST", "/rest/v1/profiles",
                jsonBody = profile,
                prefer = "resolution=merge-duplicates,return=representation",
            )
        )

    suspend fun updateProfile(userId: String, fields: Map<String, Any?>): ProfileDto? =
        parseOne(
            call(
                "PATCH", "/rest/v1/profiles",
                query = mapOf("id" to "eq.$userId"),
                jsonBody = fields,
                prefer = "return=representation",
            )
        )

    // MARK: - Posts

    suspend fun fetchPosts(statuses: List<String> = listOf("available", "sold")): List<PostDto> =
        parseList(
            call(
                "GET", "/rest/v1/posts_with_metadata",
                query = mapOf(
                    "select" to "*,profile:profiles!user_id(id,username,avatar_url)",
                    "status" to "in.(${statuses.joinToString(",")})",
                    "order" to "created_at.desc",
                ),
            )
        )

    suspend fun fetchPost(id: String): PostDto? =
        parseOne(
            call(
                "GET", "/rest/v1/posts_with_metadata",
                query = mapOf(
                    "select" to "*,profile:profiles!user_id(id,username,avatar_url)",
                    "id" to "eq.$id",
                    "limit" to "1",
                ),
            )
        )

    suspend fun fetchUserPosts(userId: String): List<PostDto> =
        parseList(
            call(
                "GET", "/rest/v1/posts_with_metadata",
                query = mapOf(
                    "select" to "*,profile:profiles!user_id(id,username,avatar_url)",
                    "user_id" to "eq.$userId",
                    "order" to "created_at.desc",
                ),
            )
        )

    suspend fun createPost(fields: Map<String, Any?>): PostDto? =
        parseOne(
            call("POST", "/rest/v1/posts", jsonBody = fields, prefer = "return=representation")
        )

    suspend fun updatePostStatus(id: String, status: String) {
        call("PATCH", "/rest/v1/posts", query = mapOf("id" to "eq.$id"), jsonBody = mapOf("status" to status))
    }

    suspend fun deletePost(postId: String) {
        runCatching { call("DELETE", "/rest/v1/likes", query = mapOf("post_id" to "eq.$postId")) }
        runCatching { call("DELETE", "/rest/v1/comments", query = mapOf("post_id" to "eq.$postId")) }
        call("DELETE", "/rest/v1/posts", query = mapOf("id" to "eq.$postId"))
    }

    // MARK: - Comments

    suspend fun fetchComments(postId: String): List<CommentDto> =
        parseList(
            call(
                "GET", "/rest/v1/comments",
                query = mapOf(
                    "select" to "*,profile:profiles!user_id(username,avatar_url)",
                    "post_id" to "eq.$postId",
                    "order" to "created_at.asc",
                ),
            )
        )

    suspend fun addComment(fields: Map<String, Any?>): CommentDto? =
        parseOne(call("POST", "/rest/v1/comments", jsonBody = fields, prefer = "return=representation"))

    suspend fun deleteComment(commentId: String) {
        call("DELETE", "/rest/v1/comments", query = mapOf("id" to "eq.$commentId"))
    }

    // MARK: - Likes

    suspend fun isLiked(postId: String, userId: String): Boolean {
        val rows: List<Map<String, Any?>> = parseList(
            call(
                "GET", "/rest/v1/likes",
                query = mapOf(
                    "select" to "id",
                    "post_id" to "eq.$postId",
                    "user_id" to "eq.$userId",
                ),
            )
        )
        return rows.isNotEmpty()
    }

    suspend fun like(postId: String, userId: String) {
        runCatching {
            call("POST", "/rest/v1/likes", jsonBody = mapOf("post_id" to postId, "user_id" to userId))
        }
    }

    suspend fun unlike(postId: String, userId: String) {
        runCatching {
            call(
                "DELETE", "/rest/v1/likes",
                query = mapOf("post_id" to "eq.$postId", "user_id" to "eq.$userId"),
            )
        }
    }

    // MARK: - RPC

    suspend fun registerStudentProfile(params: Map<String, Any?>) {
        call("POST", "/rest/v1/rpc/register_student_profile", jsonBody = params)
    }

    suspend fun deleteUserAccount() {
        call("POST", "/rest/v1/rpc/delete_user", jsonBody = emptyMap<String, Any?>())
    }

    // MARK: - 图床（与 iOS 版一致的第三方图床）

    suspend fun uploadImage(bytes: ByteArray, fileName: String, mimeType: String): String {
        val boundary = "----cczu${System.currentTimeMillis()}"
        val body = okhttp3.MultipartBody.Builder()
            .setType(okhttp3.MultipartBody.FORM)
            .addFormDataPart("outputFormatString", "webp")
            .addFormDataPart(
                "image", fileName,
                bytes.toRequestBody(mimeType.toMediaType(), 0, bytes.size)
            )
            .build()

        val request = Request.Builder()
            .url(IMAGE_HOST_URL)
            .post(body)
            .header("Accept", "application/json")
            .build()

        val response = ok.newCall(request).await()
        val text = response.use {
            val value = it.body?.string().orEmpty()
            if (!it.isSuccessful) throw IOException("图床上传失败 ${it.code}")
            value
        }

        val json = runCatching {
            gson.fromJson(text, com.google.gson.JsonObject::class.java)
        }.getOrNull()
        val url = json?.get("img_url")?.asString?.takeIf { it.isNotBlank() }
            ?: text.trim().trim('"')
        if (url.isBlank() || url.startsWith("{")) {
            throw IOException("图床返回异常: $text")
        }
        return url
    }
}

private suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    cont.invokeOnCancellation { cancel() }
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) {
            cont.resumeWith(Result.success(response))
        }

        override fun onFailure(call: Call, e: IOException) {
            if (cont.isActive) cont.resumeWithException(e)
        }
    })
}
