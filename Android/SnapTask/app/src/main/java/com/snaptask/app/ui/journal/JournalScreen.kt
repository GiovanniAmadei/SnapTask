package com.snaptask.app.ui.journal

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snaptask.app.R
import com.snaptask.app.data.model.JournalEntry
import com.snaptask.app.data.model.Mood
import java.text.SimpleDateFormat
import java.util.*

/**
 * Journal/Diary screen matching iOS JournalView.
 * Rich text editor with mood, date navigation, tags, and worth-it toggle.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun JournalScreen(
    initialDate: Date = Date(),
    entries: List<JournalEntry>,
    onSave: (JournalEntry) -> Unit,
    onDismiss: () -> Unit,
) {
    var currentDate by remember { mutableStateOf(initialDate) }
    val dateFormat = remember { SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()) }

    // Find existing entry for current date or create new
    val existingEntry = remember(entries, currentDate) {
        entries.find { entry ->
            val cal1 = Calendar.getInstance().apply { time = entry.date }
            val cal2 = Calendar.getInstance().apply { time = currentDate }
            cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
                cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
        }
    }

    var titleText by remember(existingEntry) { mutableStateOf(existingEntry?.title ?: "") }
    var contentText by remember(existingEntry) { mutableStateOf(existingEntry?.content ?: "") }
    var selectedMood by remember(existingEntry) { mutableStateOf(existingEntry?.mood) }
    var tagText by remember { mutableStateOf("") }
    var tags by remember(existingEntry) { mutableStateOf(existingEntry?.tags ?: emptyList()) }
    var worthIt by remember(existingEntry) { mutableStateOf(existingEntry?.gratitude?.isNotEmpty() ?: false) }

    fun saveCurrentEntry() {
        if (titleText.isBlank() && contentText.isBlank() && selectedMood == null) return
        val entry = (existingEntry ?: JournalEntry(date = currentDate)).copy(
            title = titleText.ifBlank { null },
            content = contentText.ifBlank { null },
            mood = selectedMood,
            tags = tags,
            gratitude = if (worthIt) listOf("yes") else emptyList(),
            lastModifiedDate = Date(),
        )
        onSave(entry)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_close)) }
            Text(
                stringResource(R.string.journal),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = {
                saveCurrentEntry()
                onDismiss()
            }) { Text(stringResource(R.string.action_save), fontWeight = FontWeight.SemiBold) }
        }

        // Main editor card
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                // Date navigation
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(
                        onClick = {
                            saveCurrentEntry()
                            val cal = Calendar.getInstance()
                            cal.time = currentDate
                            cal.add(Calendar.DAY_OF_YEAR, -1)
                            currentDate = cal.time
                        },
                        modifier = Modifier
                            .size(32.dp)
                            .background(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                                CircleShape,
                            ),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.journal_previous_day),
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }

                    Text(
                        dateFormat.format(currentDate),
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    )

                    IconButton(
                        onClick = {
                            saveCurrentEntry()
                            val cal = Calendar.getInstance()
                            cal.time = currentDate
                            cal.add(Calendar.DAY_OF_YEAR, 1)
                            currentDate = cal.time
                        },
                        modifier = Modifier
                            .size(32.dp)
                            .background(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                                CircleShape,
                            ),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = stringResource(R.string.journal_next_day),
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Title + Mood row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedTextField(
                        value = titleText,
                        onValueChange = { titleText = it },
                        placeholder = { Text(stringResource(R.string.journal_page_title_placeholder)) },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))

                    // Mood button
                    var showMoodMenu by remember { mutableStateOf(false) }
                    Box {
                        IconButton(
                            onClick = { showMoodMenu = true },
                            modifier = Modifier
                                .size(44.dp)
                                .background(
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                                    RoundedCornerShape(10.dp),
                                ),
                        ) {
                            Text(
                                selectedMood?.emoji ?: "😶",
                                fontSize = 22.sp,
                            )
                        }
                        DropdownMenu(
                            expanded = showMoodMenu,
                            onDismissRequest = { showMoodMenu = false },
                        ) {
                            Mood.entries.forEach { mood ->
                                DropdownMenuItem(
                                    text = {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        ) {
                                            Text(mood.emoji, fontSize = 20.sp)
                                            Text(mood.displayName)
                                        }
                                    },
                                    onClick = {
                                        selectedMood = if (selectedMood == mood) null else mood
                                        showMoodMenu = false
                                    },
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(12.dp))

                // Content editor
                OutlinedTextField(
                    value = contentText,
                    onValueChange = { contentText = it },
                    placeholder = {
                        Text(
                            stringResource(R.string.journal_content_placeholder),
                            fontStyle = FontStyle.Italic,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 200.dp),
                    shape = RoundedCornerShape(10.dp),
                    maxLines = Int.MAX_VALUE,
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Worth It card
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("⭐", fontSize = 24.sp)
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.journal_worth_it_title),
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    Text(
                        stringResource(R.string.journal_worth_it_subtitle),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = worthIt,
                    onCheckedChange = { worthIt = it },
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Tags section
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    stringResource(R.string.journal_tags),
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                )
                Spacer(modifier = Modifier.height(10.dp))

                // Tag input
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = tagText,
                        onValueChange = { tagText = it },
                        placeholder = { Text(stringResource(R.string.journal_add_tag_placeholder)) },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(10.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    FilledIconButton(
                        onClick = {
                            if (tagText.isNotBlank()) {
                                tags = tags + tagText.trim()
                                tagText = ""
                            }
                        },
                        modifier = Modifier.size(40.dp),
                    ) {
                        Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.content_description_add_tag), modifier = Modifier.size(18.dp))
                    }
                }

                // Tag chips
                if (tags.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(10.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        tags.forEach { tag ->
                            InputChip(
                                selected = false,
                                onClick = { tags = tags - tag },
                                label = { Text(tag, fontSize = 12.sp) },
                                trailingIcon = {
                                    Icon(
                                        Icons.Filled.Close,
                                        contentDescription = stringResource(R.string.content_description_remove),
                                        modifier = Modifier.size(14.dp),
                                    )
                                },
                                shape = RoundedCornerShape(16.dp),
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}
