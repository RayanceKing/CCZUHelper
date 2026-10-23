package com.cczu.helper.supabase

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resumeWithException

/**
 * 茶馆（Supabase）官方 Kotlin 客户端封装。
 * - 使用 supabase-kt（auth-kt + postgrest-kt）作为 REST / Auth 客户端
 * - 仅第三方图床（img.scdn.io）上传仍走 OkHttp
 */
object TeahouseSupabase {

    const val BASE_URL = "https://udrykrwyvnvmavbrdnnm.supabase.co"
    const val ANON_KEY = "sb_publishable_5mGAY5LN0WGnIIGwG30dxQ_mY7TuV_4"
    const val IMAGE_HOST_URL = "https://img.scdn.io/api/v1.php"

    /** 官方 supabase-kt 客户端（Auth + Postgrest） */
    val client: SupabaseClient = createSupabaseClient(BASE_URL, ANON_KEY) {
        install(Auth)
        install(Postgrest)
    }

    /** 用于序列化 / 反序列化 supabase-kt 的 Session，实现本地会话持久化 */
    val sessionJson: Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    private val ok: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        // 部分校园网 / 移动网络会对 HTTP/2 连接做 RST，导致登录茶馆时出现
        // "Connection reset"。强制使用 HTTP/1.1 可规避这类网络层连接重置。
        .protocols(listOf(Protocol.HTTP_1_1))
        .build()

    /** 上传图片到第三方图床（img.scdn.io），返回可访问的图片 URL */
    suspend fun uploadImage(bytes: ByteArray, fileName: String, mimeType: String): String {
        val boundary = "----cczu${System.currentTimeMillis()}"
        val body = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
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

        val url = runCatching {
            val json = Json.parseToJsonElement(text)
            json.jsonObject["img_url"]?.jsonPrimitive?.content
        }.getOrNull()?.takeIf { it.isNotBlank() } ?: text.trim().trim('"')
        if (url.isBlank() || url.startsWith("{")) {
            throw IOException("图床返回异常: $text")
        }
        return url
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
}
