package com.snaptask.app

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** One point of a chart. */
data class ChartPoint(val x: Float, val y: Float, val label: String = "")

/** Swift Charts' `LineMark` with `.catmullRom`, axes and optional area below. */
@Composable
fun LineChart(
    series: List<Pair<List<ChartPoint>, Color>>,
    modifier: Modifier = Modifier,
    yMin: Float? = null,
    yMax: Float? = null,
    showArea: Boolean = false,
    showPoints: Boolean = false,
    xLabels: List<Pair<Float, String>> = emptyList(),
    yLabelFormat: (Float) -> String = { if (it == it.toInt().toFloat()) it.toInt().toString() else "%.1f".format(it) },
    selectedX: Float? = null,
    onSelectX: ((Float?) -> Unit)? = null,
) {
    val measurer = rememberTextMeasurer()
    val grid = Color.SysGray.copy(alpha = 0.2f)
    val labelColor = Color.Secondary
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = labelColor)
    val progress by animateFloatAsState(1f, tween(500), label = "line")
    val allPoints = series.flatMap { it.first }
    if (allPoints.isEmpty()) return
    val minY = yMin ?: allPoints.minOf { it.y }.let { if (it > 0) 0f else it }
    val maxY = (yMax ?: allPoints.maxOf { it.y }).let { if (it <= minY) minY + 1f else it }
    val minX = allPoints.minOf { it.x }
    val maxX = allPoints.maxOf { it.x }.let { if (it <= minX) minX + 1f else it }

    Canvas(
        modifier.then(
            if (onSelectX != null) Modifier.pointerInput(minX, maxX) {
                val left = 30.dp.toPx()
                val width = size.width - left - 8.dp.toPx()
                fun value(x: Float) = (minX + ((x - left) / width).coerceIn(0f, 1f) * (maxX - minX))
                detectDragGestures(
                    onDragStart = { onSelectX(value(it.x)) },
                    onDragEnd = { onSelectX(null) },
                    onDragCancel = { onSelectX(null) },
                    onDrag = { change, _ -> onSelectX(value(change.position.x)) },
                )
            } else Modifier
        )
    ) {
        val left = 30.dp.toPx()
        val bottom = if (xLabels.isEmpty()) 6.dp.toPx() else 20.dp.toPx()
        val top = 6.dp.toPx()
        val right = 8.dp.toPx()
        val width = size.width - left - right
        val height = size.height - top - bottom
        fun px(x: Float) = left + (x - minX) / (maxX - minX) * width
        fun py(y: Float) = top + height - (y - minY) / (maxY - minY) * height

        for (index in 0..4) {
            val value = minY + (maxY - minY) * index / 4
            val y = py(value)
            drawLine(grid, Offset(left, y), Offset(left + width, y), 0.5.dp.toPx())
            val text = measurer.measure(yLabelFormat(value), labelStyle)
            drawText(text, topLeft = Offset(left - text.size.width - 4.dp.toPx(), y - text.size.height / 2f))
        }
        var lastRight = -1000f
        for ((x, label) in xLabels) {
            val text = measurer.measure(label, labelStyle)
            val position = (px(x) - text.size.width / 2f).coerceIn(0f, size.width - text.size.width)
            if (position > lastRight + 4.dp.toPx()) {
                drawText(text, topLeft = Offset(position, top + height + 6.dp.toPx()))
                lastRight = position + text.size.width
            }
        }

        for ((points, color) in series) {
            if (points.isEmpty()) continue
            val sorted = points.sortedBy { it.x }
            val path = smoothPath(sorted.map { Offset(px(it.x), py(it.y)) })
            if (showArea && sorted.size > 1) {
                val area = Path().apply {
                    addPath(path)
                    lineTo(px(sorted.last().x), top + height)
                    lineTo(px(sorted.first().x), top + height)
                    close()
                }
                drawPath(area, Brush.verticalGradient(listOf(color.copy(alpha = 0.3f * progress), color.copy(alpha = 0.02f)), top, top + height))
            }
            drawPath(path, color.copy(alpha = progress), style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            if (showPoints || sorted.size == 1) {
                sorted.forEach { drawCircle(color, 3.dp.toPx(), Offset(px(it.x), py(it.y))) }
            }
        }
        if (selectedX != null) {
            val x = px(selectedX)
            drawLine(labelColor.copy(alpha = 0.5f), Offset(x, top), Offset(x, top + height), 1.dp.toPx())
        }
    }
}

private fun smoothPath(points: List<Offset>): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points[0].x, points[0].y)
    for (index in 0 until points.size - 1) {
        val p0 = points.getOrElse(index - 1) { points[index] }
        val p1 = points[index]
        val p2 = points[index + 1]
        val p3 = points.getOrElse(index + 2) { p2 }
        path.cubicTo(
            p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
            p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
            p2.x, p2.y,
        )
    }
    return path
}

data class BarValue(val label: String, val value: Float, val color: Color, val secondary: Float = 0f, val secondaryColor: Color = Color.Transparent)

/** Swift Charts' `BarMark`. */
@Composable
fun BarChart(
    bars: List<BarValue>,
    modifier: Modifier = Modifier,
    corner: Dp = 4.dp,
    labelEvery: Int = 1,
    showYAxis: Boolean = true,
    yLabelFormat: (Float) -> String = { if (it == it.toInt().toFloat()) it.toInt().toString() else "%.1f".format(it) },
    maxValue: Float? = null,
    selectedIndex: Int? = null,
    onSelect: ((Int?) -> Unit)? = null,
) {
    val measurer = rememberTextMeasurer()
    val grid = Color.SysGray.copy(alpha = 0.2f)
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = Color.Secondary)
    val progress by animateFloatAsState(1f, tween(450), label = "bars")
    val top = (maxValue ?: bars.maxOfOrNull { it.value + it.secondary } ?: 0f).let { if (it <= 0f) 1f else it }

    Canvas(
        modifier.then(
            if (onSelect != null) Modifier.pointerInput(bars.size) {
                val left = if (showYAxis) 30.dp.toPx() else 0f
                detectTapGestures { offset ->
                    val slot = (size.width - left) / bars.size.coerceAtLeast(1)
                    val index = ((offset.x - left) / slot).toInt()
                    onSelect(if (index == selectedIndex || index !in bars.indices) null else index)
                }
            } else Modifier
        )
    ) {
        val left = if (showYAxis) 30.dp.toPx() else 0f
        val bottom = 20.dp.toPx()
        val height = size.height - bottom - 4.dp.toPx()
        val width = size.width - left
        val slot = width / bars.size.coerceAtLeast(1)
        val barWidth = (slot * 0.62f).coerceAtMost(28.dp.toPx())
        if (showYAxis) {
            for (index in 0..4) {
                val value = top * index / 4
                val y = 4.dp.toPx() + height - height * index / 4
                drawLine(grid, Offset(left, y), Offset(size.width, y), 0.5.dp.toPx())
                val text = measurer.measure(yLabelFormat(value), labelStyle)
                drawText(text, topLeft = Offset(left - text.size.width - 4.dp.toPx(), y - text.size.height / 2f))
            }
        }
        bars.forEachIndexed { index, bar ->
            val x = left + slot * index + (slot - barWidth) / 2
            val h = height * (bar.value / top) * progress
            val alpha = if (selectedIndex == null || selectedIndex == index) 1f else 0.4f
            val base = 4.dp.toPx() + height
            if (bar.secondary > 0f) {
                val h2 = height * (bar.secondary / top) * progress
                drawRoundRect(bar.secondaryColor.copy(alpha = bar.secondaryColor.alpha * alpha), Offset(x, base - h - h2), Size(barWidth, h2), CornerRadius(corner.toPx()))
            }
            if (h > 0f) drawRoundRect(bar.color.copy(alpha = bar.color.alpha * alpha), Offset(x, base - h), Size(barWidth, h), CornerRadius(corner.toPx()))
            if (labelEvery > 0 && index % labelEvery == 0 && bar.label.isNotEmpty()) {
                val text = measurer.measure(bar.label, labelStyle)
                drawText(text, topLeft = Offset(x + barWidth / 2 - text.size.width / 2f, base + 5.dp.toPx()))
            }
        }
    }
}

data class PieSlice(val value: Float, val color: Color)

/** Swift Charts' `SectorMark` with an inner radius. */
@Composable
fun DonutChart(
    slices: List<PieSlice>,
    modifier: Modifier = Modifier,
    thickness: Dp = 26.dp,
    gapDegrees: Float = 1.5f,
    selectedIndex: Int? = null,
    onSelect: ((Int?) -> Unit)? = null,
    center: @Composable BoxScope.() -> Unit = {},
) {
    val total = slices.sumOf { it.value.toDouble() }.toFloat().coerceAtLeast(0.0001f)
    val progress by animateFloatAsState(1f, tween(600), label = "donut")
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .fillMaxSize()
                .then(
                    if (onSelect != null) Modifier.pointerInput(slices) {
                        detectTapGestures { offset ->
                            val dx = offset.x - size.width / 2f
                            val dy = offset.y - size.height / 2f
                            val distance = sqrt(dx * dx + dy * dy)
                            val outer = min(size.width, size.height) / 2f
                            if (distance > outer || distance < outer - thickness.toPx() * 1.4f) {
                                onSelect(null)
                                return@detectTapGestures
                            }
                            var angle = (atan2(dy, dx) * 180f / PI.toFloat() + 90f + 360f) % 360f
                            var index = 0
                            for (slice in slices) {
                                val sweep = slice.value / total * 360f
                                if (angle < sweep) break
                                angle -= sweep
                                index++
                            }
                            onSelect(if (index == selectedIndex) null else index.takeIf { it in slices.indices })
                        }
                    } else Modifier
                )
        ) {
            val stroke = thickness.toPx()
            val diameter = min(size.width, size.height) - stroke
            val topLeft = Offset((size.width - diameter) / 2, (size.height - diameter) / 2)
            var start = -90f
            slices.forEachIndexed { index, slice ->
                val sweep = slice.value / total * 360f * progress
                val selected = selectedIndex == index
                val width = if (selected) stroke * 1.25f else stroke
                val alpha = if (selectedIndex == null || selected) 1f else 0.4f
                drawArc(
                    slice.color.copy(alpha = alpha),
                    start + gapDegrees / 2,
                    (sweep - gapDegrees).coerceAtLeast(0.1f),
                    false,
                    topLeft,
                    Size(diameter, diameter),
                    style = Stroke(width),
                )
                start += sweep
            }
        }
        center()
    }
}
