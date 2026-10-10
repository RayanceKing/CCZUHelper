package com.cczu.helper.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF4E7CF6),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFDCE5FF),
    secondary = Color(0xFF4ECDC4),
    background = Color(0xFFF5F6FA),
    surface = Color.White,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF8AB0FF),
    onPrimary = Color(0xFF10234A),
    primaryContainer = Color(0xFF1E3A72),
    secondary = Color(0xFF4ECDC4),
    background = Color(0xFF101318),
    surface = Color(0xFF181B22),
)

val AppTypography = Typography()

@Composable
fun CCZUHelperTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = AppTypography,
        content = content,
    )
}
