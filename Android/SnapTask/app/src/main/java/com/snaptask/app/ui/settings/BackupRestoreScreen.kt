package com.snaptask.app.ui.settings

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R

/**
 * Backup & Restore: export data as JSON (share) and import from JSON file.
 */
@Composable
fun BackupRestoreScreen(
    viewModel: SettingsViewModel = hiltViewModel(),
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val exportJson by viewModel.backupExportJson.collectAsState()
    val restoreResult by viewModel.backupRestoreResult.collectAsState()

    val openDocument = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val json = stream.bufferedReader().readText()
                viewModel.restoreFromBackup(json)
            }
        }
    }

    LaunchedEffect(exportJson) {
        if (exportJson != null) {
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, exportJson)
                putExtra(Intent.EXTRA_SUBJECT, "SnapTask backup")
            }
            context.startActivity(Intent.createChooser(shareIntent, context.getString(R.string.backup_share_title)))
            viewModel.clearBackupExport()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
    ) {
        Text(
            text = stringResource(R.string.settings_backup_restore),
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.settings_backup_restore_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(24.dp))

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Button(
                    onClick = { viewModel.exportBackup() },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.FileDownload, null, Modifier.padding(end = 8.dp))
                    Text(stringResource(R.string.backup_export))
                }
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(
                    onClick = { openDocument.launch(arrayOf("application/json", "text/plain", "*/*")) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.FileUpload, null, Modifier.padding(end = 8.dp))
                    Text(stringResource(R.string.backup_import))
                }
            }
        }

        restoreResult?.fold(
            onSuccess = {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.backup_restore_success),
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodyMedium,
                )
            },
            onFailure = { e ->
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.backup_restore_error, e.message ?: ""),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            },
        )

        Spacer(modifier = Modifier.height(24.dp))
        OutlinedButton(onClick = onDismiss) {
            Text(stringResource(R.string.action_done))
        }
    }
}
