package com.snaptask.app.ui.onboarding

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import com.snaptask.app.R
import kotlinx.coroutines.launch

/**
 * Welcome/Onboarding screen matching iOS WelcomeView.
 * Multi-page onboarding flow with illustrations and descriptions.
 */

private data class OnboardingPage(
    val title: String,
    val description: String,
    val icon: ImageVector,
    val gradient: List<Color>,
)

@Composable
fun WelcomeScreen(
    onComplete: () -> Unit,
) {
    val pages = listOf(
        OnboardingPage(
            title = stringResource(R.string.welcome_page1_title),
            description = stringResource(R.string.welcome_page1_desc),
            icon = Icons.Filled.CheckCircle,
            gradient = listOf(Color(0xFF4CAF50), Color(0xFF2E7D32)),
        ),
        OnboardingPage(
            title = stringResource(R.string.welcome_page2_title),
            description = stringResource(R.string.welcome_page2_desc),
            icon = Icons.Filled.Timer,
            gradient = listOf(Color(0xFFFF5722), Color(0xFFD84315)),
        ),
        OnboardingPage(
            title = stringResource(R.string.welcome_page3_title),
            description = stringResource(R.string.welcome_page3_desc),
            icon = Icons.Filled.EmojiEvents,
            gradient = listOf(Color(0xFFFF9800), Color(0xFFE65100)),
        ),
        OnboardingPage(
            title = stringResource(R.string.welcome_page4_title),
            description = stringResource(R.string.welcome_page4_desc),
            icon = Icons.Filled.AccountBalance,
            gradient = listOf(Color(0xFF2196F3), Color(0xFF1565C0)),
        ),
        OnboardingPage(
            title = stringResource(R.string.welcome_page5_title),
            description = stringResource(R.string.welcome_page5_desc),
            icon = Icons.Filled.BarChart,
            gradient = listOf(Color(0xFF9C27B0), Color(0xFF6A1B9A)),
        ),
    )

    val pagerState = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        // Skip button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.End,
        ) {
            TextButton(onClick = onComplete) {
                Text(stringResource(R.string.welcome_skip), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        // Pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) { pageIndex ->
            val page = pages[pageIndex]
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                // Icon circle
                Box(
                    modifier = Modifier
                        .size(120.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(page.gradient),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        page.icon,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(56.dp),
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))

                Text(
                    page.title,
                    style = MaterialTheme.typography.headlineSmall.copy(
                        fontWeight = FontWeight.Bold,
                    ),
                    textAlign = TextAlign.Center,
                )

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    page.description,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 22.sp,
                )
            }
        }

        // Page indicator
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp),
            horizontalArrangement = Arrangement.Center,
        ) {
            repeat(pages.size) { index ->
                val isSelected = pagerState.currentPage == index
                Box(
                    modifier = Modifier
                        .padding(horizontal = 4.dp)
                        .size(if (isSelected) 10.dp else 6.dp)
                        .clip(CircleShape)
                        .background(
                            if (isSelected) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                        ),
                )
            }
        }

        // Bottom buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            if (pagerState.currentPage > 0) {
                OutlinedButton(
                    onClick = {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage - 1) }
                    },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.width(100.dp),
                ) {
                    Text(stringResource(R.string.welcome_back))
                }
            } else {
                Spacer(modifier = Modifier.width(100.dp))
            }

            if (pagerState.currentPage < pages.size - 1) {
                Button(
                    onClick = {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    },
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.width(100.dp),
                ) {
                    Text(stringResource(R.string.welcome_next))
                }
            } else {
                Button(
                    onClick = onComplete,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.width(140.dp),
                ) {
                    Text(stringResource(R.string.welcome_get_started), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
