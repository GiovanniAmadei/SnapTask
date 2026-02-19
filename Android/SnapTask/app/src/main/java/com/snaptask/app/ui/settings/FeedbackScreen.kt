package com.snaptask.app.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Feedback screen matching iOS FeedbackView / NewFeedbackView.
 * User feedback submission form.
 */

enum class FeedbackType(val displayName: String, val emoji: String) {
    BUG("Bug Report", "🐛"),
    FEATURE("Feature Request", "💡"),
    IMPROVEMENT("Improvement", "🔧"),
    OTHER("Other", "💬");
}

@Composable
fun FeedbackScreen(
    onSubmit: (type: FeedbackType, message: String, email: String) -> Unit,
    onDismiss: () -> Unit,
) {
    var selectedType by remember { mutableStateOf(FeedbackType.BUG) }
    var message by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var showConfirmation by remember { mutableStateOf(false) }

    if (showConfirmation) {
        AlertDialog(
            onDismissRequest = { showConfirmation = false; onDismiss() },
            confirmButton = {
                TextButton(onClick = { showConfirmation = false; onDismiss() }) {
                    Text("OK")
                }
            },
            title = { Text("Thank You! 🎉") },
            text = { Text("Your feedback has been submitted. We appreciate your input!") },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Send Feedback",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Feedback type
        Text(
            "FEEDBACK TYPE",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FeedbackType.entries.forEach { type ->
                FilterChip(
                    selected = selectedType == type,
                    onClick = { selectedType = type },
                    label = { Text("${type.emoji} ${type.displayName}", style = MaterialTheme.typography.labelSmall) },
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.weight(1f),
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Message
        Text(
            "YOUR MESSAGE",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        OutlinedTextField(
            value = message,
            onValueChange = { message = it },
            placeholder = { Text("Tell us what's on your mind…") },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 150.dp),
            shape = RoundedCornerShape(12.dp),
            maxLines = Int.MAX_VALUE,
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Email (optional)
        Text(
            "EMAIL (OPTIONAL)",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            placeholder = { Text("your@email.com") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            singleLine = true,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Submit button
        Button(
            onClick = {
                if (message.isNotBlank()) {
                    onSubmit(selectedType, message, email)
                    showConfirmation = true
                }
            },
            enabled = message.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Submit Feedback", fontWeight = FontWeight.SemiBold)
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}
