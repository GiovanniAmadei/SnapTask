package com.snaptask.app

import android.util.Log
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Test

/**
 * Opens one screen and uses everything on it, a few levels deep. It reports crashes and controls
 * that change nothing. Run by tools (one screen per process):
 * am instrument -w -e screen TaskFormView.new -e skip "a|b" com.snaptask.app.test/androidx.test.runner.AndroidJUnitRunner
 */
class ExploreTest {
    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    private var generation by mutableStateOf(0)
    private val skip = Regex("Photos|Camera|Contact Support|Rate App|Redeem|Manage Subscriptions|Submit|Purchase|Start Free|Subscribe|Restore")

    private data class Step(val kind: String, val label: String, val ordinal: Int) {
        override fun toString() = "$kind:$label#$ordinal"
    }

    private fun log(line: String) = Log.i("EXPLORE", line)

    private fun clickables(): List<SemanticsNode> =
        rule.onAllNodes(hasClickAction()).fetchSemanticsNodes(atLeastOneRootRequired = false)

    private fun labelOf(node: SemanticsNode): String {
        val text = node.config.getOrNull(SemanticsProperties.Text)?.joinToString(" ") { it.text } ?: ""
        val description = node.config.getOrNull(SemanticsProperties.ContentDescription)?.joinToString(" ") ?: ""
        val label = (text + description).ifEmpty { collect(node) }.take(40)
        return label.replace(Regex("\\d+"), "#").ifEmpty { "(icon)" }
    }

    private fun collect(node: SemanticsNode): String = node.children.joinToString(" ") { child ->
        (child.config.getOrNull(SemanticsProperties.Text)?.joinToString(" ") { it.text } ?: "") + collect(child)
    }.trim()

    /** What the screen shows, in words and states. */
    private fun fingerprint(): Int {
        val parts = ArrayList<String>()
        fun walk(node: SemanticsNode) {
            node.config.getOrNull(SemanticsProperties.Text)?.forEach { parts += it.text }
            node.config.getOrNull(SemanticsProperties.EditableText)?.let { parts += it.text }
            node.config.getOrNull(SemanticsProperties.ToggleableState)?.let { parts += it.name }
            node.config.getOrNull(SemanticsProperties.Selected)?.let { parts += it.toString() }
            node.config.getOrNull(SemanticsProperties.ContentDescription)?.let { parts += it }
            node.children.forEach(::walk)
        }
        rule.onAllNodes(isRoot()).fetchSemanticsNodes(atLeastOneRootRequired = false).forEach(::walk)
        return parts.joinToString("|").replace(Regex("\\d+"), "#").hashCode()
    }

    private fun steps(): List<Step> {
        val seen = HashMap<String, Int>()
        return clickables().mapNotNull { node ->
            val label = labelOf(node)
            val ordinal = seen.getOrDefault(label, 0)
            seen[label] = ordinal + 1
            if (skip.containsMatchIn(label) || ordinal > 2) null else Step("tap", label, ordinal)
        }
    }

    private fun perform(step: Step): Boolean {
        val nodes = clickables()
        var seen = 0
        var index = -1
        for ((i, node) in nodes.withIndex()) {
            if (labelOf(node) == step.label) {
                if (seen == step.ordinal) {
                    index = i
                    break
                }
                seen++
            }
        }
        if (index < 0) return false
        val target = rule.onAllNodes(hasClickAction())[index]
        runCatching { target.performScrollTo() }
        rule.waitForIdle()
        if (step.kind == "hold") target.performTouchInput { longClick() } else target.performClick()
        rule.waitForIdle()
        return true
    }

    private fun reset() {
        generation++
        rule.waitForIdle()
    }

    @Test
    fun explore() {
        val args = InstrumentationRegistry.getArguments()
        val name = args.getString("screen") ?: return
        val deadline = System.currentTimeMillis() + (args.getString("seconds")?.toLong() ?: 75L) * 1000
        val skipped = String(android.util.Base64.decode(args.getString("skip") ?: "", android.util.Base64.URL_SAFE)).split("~").filter { it.isNotEmpty() }.toSet()
        val screen = GalleryScreens.all[name]
        if (screen == null) {
            log("UNKNOWN $name")
            return
        }
        rule.setContent {
            AppTheme {
                key(generation) {
                    val presenter = remember { Presenter() }
                    CompositionLocalProvider(LocalPresenter provides presenter) {
                        presenter.Host {
                            Box(Modifier.fillMaxSize().background(LocalTheme.current.backgroundColor)) {
                                NavigationStack { screen() }
                            }
                        }
                    }
                }
            }
        }
        rule.waitForIdle()
        val visited = hashSetOf(fingerprint())
        val queue = ArrayDeque<List<Step>>().apply { add(emptyList()) }
        var actions = 0
        while (queue.isNotEmpty() && System.currentTimeMillis() < deadline) {
            val path = queue.removeFirst()
            reset()
            if (!replay(path)) continue
            val choices = steps()
            for (choice in choices) {
                if (System.currentTimeMillis() > deadline) break
                val kinds = if (path.size <= 1) listOf("tap", "hold") else listOf("tap")
                for (kind in kinds) {
                    val step = choice.copy(kind = kind)
                    val key = (path + step).joinToString(" > ")
                    if (key in skipped) continue
                    reset()
                    if (!replay(path)) continue
                    val before = fingerprint()
                    log("TRY $key")
                    val done = try {
                        perform(step)
                    } catch (error: AssertionError) {
                        log("BLOCKED $key :: ${error.message?.lineSequence()?.firstOrNull()}")
                        false
                    }
                    if (!done) continue
                    actions++
                    val after = fingerprint()
                    if (after == before) {
                        if (kind == "tap") log("DEAD [$name] $key")
                    } else if (after !in visited) {
                        visited += after
                        if (path.size < 2) queue.add(path + step)
                    }
                }
            }
        }
        log("DONE [$name] actions=$actions states=${visited.size}")
    }

    private fun replay(path: List<Step>): Boolean = path.all { perform(it) }
}
