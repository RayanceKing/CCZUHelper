package com.cczu.helper.data

/** 统一的界面加载状态 */
sealed interface UiState<out T> {
    data object Idle : UiState<Nothing>
    data object Loading : UiState<Nothing>
    data class Success<T>(val data: T) : UiState<T>
    data class Error(val message: String) : UiState<Nothing>
}

fun Throwable.readableMessage(): String = message ?: localizedMessage ?: javaClass.simpleName
