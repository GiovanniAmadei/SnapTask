package com.snaptask.app.ui.statistics

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Date

// ---- Color Parsing ----

fun parseColor(hex: String): Color {
    return try {
        val cleanHex = hex.removePrefix("#")
        val colorLong = when (cleanHex.length) {
            6 -> ("FF$cleanHex").toLong(16)
            8 -> cleanHex.toLong(16)
            else -> 0xFF6366F1 // default indigo
        }
        Color(colorLong)
    } catch (e: Exception) {
        Color(0xFF6366F1)
    }
}

// ---- Pie Chart ----

data class PieChartSlice(
    val value: Float,
    val color: Color,
    val label: String,
)

@Composable
fun PieChart(
    slices: List<PieChartSlice>,
    modifier: Modifier = Modifier,
    innerRadiusRatio: Float = 0.618f,
    animate: Boolean = true,
) {
    val total = slices.sumOf { it.value.toDouble() }.toFloat()
    if (total <= 0f || slices.isEmpty()) return

    val animationProgress = if (animate) {
        val anim = remember { Animatable(0f) }
        LaunchedEffect(slices) {
            anim.snapTo(0f)
            anim.animateTo(1f, animationSpec = tween(800, easing = FastOutSlowInEasing))
        }
        anim.value
    } else 1f

    Canvas(modifier = modifier) {
        val diameter = minOf(size.width, size.height)
        val radius = diameter / 2f
        val innerRadius = radius * innerRadiusRatio
        val center = Offset(size.width / 2f, size.height / 2f)
        val gapAngle = 1.5f

        var currentAngle = -90f
        val totalGap = gapAngle * slices.size
        val availableSweep = (360f - totalGap) * animationProgress

        for (slice in slices) {
            val sweepAngle = (slice.value / total) * availableSweep
            drawArc(
                color = slice.color,
                startAngle = currentAngle,
                sweepAngle = sweepAngle,
                useCenter = true,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = Size(diameter, diameter)
            )
            currentAngle += sweepAngle + gapAngle
        }

        // Inner circle for donut effect
        drawCircle(
            color = Color.Transparent,
            radius = innerRadius,
            center = center,
            blendMode = androidx.compose.ui.graphics.BlendMode.Clear
        )
    }
}

// ---- Bar Chart ----

data class BarChartData(
    val label: String,
    val primaryValue: Float,
    val secondaryValue: Float = 0f, // for stacked bars
    val primaryColor: Color = Color(0xFF6366F1),
    val secondaryColor: Color = Color.Gray.copy(alpha = 0.3f),
)

@Composable
fun BarChart(
    data: List<BarChartData>,
    modifier: Modifier = Modifier,
    animate: Boolean = true,
    showLabels: Boolean = true,
    barCornerRadius: Float = 8f,
) {
    if (data.isEmpty()) return

    val maxValue = data.maxOf { it.primaryValue + it.secondaryValue }.coerceAtLeast(1f)

    val animationProgress = if (animate) {
        val anim = remember { Animatable(0f) }
        LaunchedEffect(data) {
            anim.snapTo(0f)
            anim.animateTo(1f, animationSpec = tween(800, easing = FastOutSlowInEasing))
        }
        anim.value
    } else 1f

    val textColor = MaterialTheme.colorScheme.onSurface

    Column(modifier = modifier) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) {
            val barAreaHeight = size.height
            val barWidth = (size.width / data.size) * 0.65f
            val barSpacing = size.width / data.size

            data.forEachIndexed { index, item ->
                val x = barSpacing * index + (barSpacing - barWidth) / 2f
                val totalHeight = ((item.primaryValue + item.secondaryValue) / maxValue) * barAreaHeight * animationProgress
                val primaryHeight = (item.primaryValue / maxValue) * barAreaHeight * animationProgress

                // Secondary (incomplete) bar
                if (item.secondaryValue > 0) {
                    drawRoundRect(
                        color = item.secondaryColor,
                        topLeft = Offset(x, barAreaHeight - totalHeight),
                        size = Size(barWidth, totalHeight),
                        cornerRadius = CornerRadius(barCornerRadius, barCornerRadius)
                    )
                }

                // Primary (completed) bar
                if (primaryHeight > 0) {
                    drawRoundRect(
                        color = item.primaryColor,
                        topLeft = Offset(x, barAreaHeight - primaryHeight),
                        size = Size(barWidth, primaryHeight),
                        cornerRadius = CornerRadius(barCornerRadius, barCornerRadius)
                    )
                }
            }
        }

        if (showLabels) {
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                data.forEach { item ->
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

// ---- Line Chart ----

data class LineChartPoint(
    val x: Float,
    val y: Float,
    val date: Date? = null,
)

data class LineChartSeries(
    val points: List<LineChartPoint>,
    val color: Color,
    val label: String = "",
    val lineWidth: Float = 3f,
    val showPoints: Boolean = true,
)

@Composable
fun LineChart(
    series: List<LineChartSeries>,
    modifier: Modifier = Modifier,
    animate: Boolean = true,
    showAxes: Boolean = false,
    yDomain: ClosedFloatingPointRange<Float>? = null,
) {
    if (series.isEmpty() || series.all { it.points.isEmpty() }) return

    val allPoints = series.flatMap { it.points }
    val minX = allPoints.minOf { it.x }
    val maxX = allPoints.maxOf { it.x }.let { if (it == minX) minX + 1f else it }
    val minY = yDomain?.start ?: allPoints.minOf { it.y }
    val maxY = yDomain?.endInclusive ?: allPoints.maxOf { it.y }.let { if (it == minY) minY + 1f else it }

    val animationProgress = if (animate) {
        val anim = remember { Animatable(0f) }
        LaunchedEffect(series) {
            anim.snapTo(0f)
            anim.animateTo(1f, animationSpec = tween(800, easing = FastOutSlowInEasing))
        }
        anim.value
    } else 1f

    Canvas(modifier = modifier) {
        val chartWidth = size.width
        val chartHeight = size.height
        val paddingH = 4f
        val drawWidth = chartWidth - paddingH * 2

        fun mapX(x: Float) = paddingH + ((x - minX) / (maxX - minX)) * drawWidth
        fun mapY(y: Float) = chartHeight - ((y - minY) / (maxY - minY)) * chartHeight

        for (s in series) {
            if (s.points.size < 2) continue

            val sortedPoints = s.points.sortedBy { it.x }
            val visibleCount = (sortedPoints.size * animationProgress).toInt().coerceAtLeast(2)
            val visiblePoints = sortedPoints.take(visibleCount)

            val path = Path()
            visiblePoints.forEachIndexed { index, point ->
                val px = mapX(point.x)
                val py = mapY(point.y)
                if (index == 0) path.moveTo(px, py) else path.lineTo(px, py)
            }

            drawPath(
                path = path,
                color = s.color,
                style = Stroke(width = s.lineWidth, cap = StrokeCap.Round)
            )

            if (s.showPoints) {
                visiblePoints.forEach { point ->
                    val px = mapX(point.x)
                    val py = mapY(point.y)
                    drawCircle(color = s.color, radius = 4f, center = Offset(px, py))
                }
            }
        }
    }
}

// ---- Heat Map Grid ----

data class HeatMapCell(
    val date: Date,
    val isCompleted: Boolean,
    val isScheduled: Boolean,
)

@Composable
fun HeatMapGrid(
    cells: List<List<HeatMapCell>>, // weeks x days
    categoryColor: Color,
    modifier: Modifier = Modifier,
    cellSize: Dp = 10.dp,
    cellSpacing: Dp = 2.dp,
) {
    val completedColor = categoryColor
    val missedColor = Color(0xFFEF4444).copy(alpha = 0.3f)
    val emptyColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)

    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(cellSpacing)
    ) {
        cells.forEach { week ->
            Column(verticalArrangement = Arrangement.spacedBy(cellSpacing)) {
                week.forEach { cell ->
                    val color = when {
                        cell.isCompleted -> completedColor
                        cell.isScheduled -> missedColor
                        else -> emptyColor
                    }
                    Box(
                        modifier = Modifier
                            .size(cellSize)
                            .clip(RoundedCornerShape(2.dp))
                            .background(color)
                    )
                }
            }
        }
    }
}

// ---- Legend Item ----

@Composable
fun ChartLegendItem(
    color: Color,
    label: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}
