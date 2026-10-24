package com.auramusic.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = AuraPrimary,
    secondary = AuraAccent,
    tertiary = AuraPink,
    background = AuraBackground,
    surface = AuraSurface,
    onPrimary = AuraTextPrimary,
    onSecondary = AuraBackground,
    onTertiary = AuraTextPrimary,
    onBackground = AuraTextPrimary,
    onSurface = AuraTextPrimary
)

@Composable
fun AuraMusicTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
