package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Motivational Quote Card matching iOS MotivationalQuoteView.
 * Displays a daily inspirational quote with refresh button.
 */
@Composable
fun MotivationalQuoteCard(
    quote: String,
    author: String,
    isLoading: Boolean = false,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        modifier = modifier.fillMaxWidth(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF667EEA),
                            Color(0xFF764BA2),
                        ),
                    ),
                    shape = RoundedCornerShape(18.dp),
                )
                .padding(20.dp),
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Quote icon
                Icon(
                    Icons.Filled.FormatQuote,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f),
                    modifier = Modifier.size(28.dp),
                )

                Spacer(modifier = Modifier.height(8.dp))

                if (isLoading) {
                    CircularProgressIndicator(
                        color = Color.White,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                } else {
                    // Quote text
                    Text(
                        "\"$quote\"",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontStyle = FontStyle.Italic,
                            fontSize = 15.sp,
                            lineHeight = 22.sp,
                        ),
                        color = Color.White,
                        textAlign = TextAlign.Center,
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Author
                    Text(
                        "— $author",
                        style = MaterialTheme.typography.bodySmall.copy(
                            fontWeight = FontWeight.SemiBold,
                        ),
                        color = Color.White.copy(alpha = 0.8f),
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Refresh button
                IconButton(
                    onClick = onRefresh,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.White.copy(alpha = 0.15f)),
                ) {
                    Icon(
                        Icons.Filled.Refresh,
                        contentDescription = "New Quote",
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
}
