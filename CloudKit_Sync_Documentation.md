# CloudKit Sync Documentation - SnapTask

## Overview

SnapTask implements a comprehensive CloudKit synchronization system that keeps user data synchronized across all Apple devices (iPhone, iPad, Mac, Apple Watch) using iCloud. The sync system is designed to be robust, conflict-aware, and privacy-focused with end-to-end encryption.

## Architecture

### Core Components

1. **CloudKitService** - Main sync coordinator
2. **CloudKitSettingsManager** - App settings synchronization
3. **CloudKitSyncUtilities** - Conflict resolution and data validation
4. **TaskManager/RewardManager/CategoryManager** - Data managers with sync integration

### Sync Strategy

- **Incremental Sync**: Uses CloudKit change tokens for efficient delta updates
- **Conflict Resolution**: Last-write-wins with intelligent merging for specific data types
- **Batch Operations**: Processes large datasets in manageable chunks
- **Error Recovery**: Automatic retry with exponential backoff

## Synchronized Data Types

### 1. Tasks (TodoTask)
- **Record Type**: `TodoTask`
- **Key Fields**: name, description, startTime, duration, priority, completions, subtasks
- **Conflict Resolution**: Merge strategy for completions and subtasks
- **Validation**: Name length (max 500), duration limits

### 2. Rewards
- **Record Type**: `Reward`
- **Key Fields**: name, description, pointsCost, frequency, redemptions
- **Conflict Resolution**: Merge redemption dates from all devices
- **Validation**: Points cost limits, name length

### 3. Categories
- **Record Type**: `Category`
- **Key Fields**: name, color
- **Conflict Resolution**: Prefer local changes
- **Validation**: Name uniqueness, color format validation

### 4. Points History
- **Record Type**: `PointsHistory`
- **Key Fields**: date, points, frequency
- **Conflict Resolution**: Additive merge (no overwrite of existing dates)
- **Validation**: Point limits, date validation

### 5. App Settings
- **Record Type**: `AppSettings`
- **Key Fields**: All user preferences and customizations
- **Conflict Resolution**: Most recent timestamp wins
- **Validation**: Setting value ranges and types

## Conflict Resolution

### Task Conflicts
When the same task is modified on multiple devices:
1. **Metadata**: Most recent `lastModifiedDate` wins
2. **Completions**: Union of all completion dates and statuses
3. **Subtasks**: Merge by ID, prefer completed state

### Reward Conflicts
1. **Properties**: Most recent modification wins
2. **Redemptions**: Union of all redemption dates

### Points History Conflicts
1. **Existing Dates**: Never overwrite existing point entries
2. **New Dates**: Add points for dates not present locally

## Setup and Configuration

### Enable CloudKit Sync
```swift
// Enable sync programmatically
CloudKitService.shared.enableCloudKitSync()

// Disable sync
CloudKitService.shared.disableCloudKitSync()
```

### User Interface
Users can manage sync settings through:
- Settings → Synchronization → iCloud Sync
- Toggle sync on/off
- View sync status and details
- Manual sync trigger

### Requirements
- iCloud account signed in
- Network connectivity
- Sufficient iCloud storage

## Error Handling

### Common Errors and Solutions

#### Network Errors
- **Error**: `networkFailure`, `networkUnavailable`
- **Handling**: Automatic retry with exponential backoff
- **User Action**: Check internet connection

#### Authentication Errors
- **Error**: `notAuthenticated`
- **Handling**: Prompt user to sign into iCloud
- **User Action**: Go to Settings → Apple ID

#### Storage Quota Exceeded
- **Error**: `quotaExceeded`
- **Handling**: Graceful degradation, local storage continues
- **User Action**: Free up iCloud storage or upgrade plan

#### Zone/Record Conflicts
- **Error**: `serverRecordChanged`
- **Handling**: Automatic conflict resolution and re-sync
- **User Action**: None required

## Privacy and Security

### End-to-End Encryption
- All data is encrypted using CloudKit's default encryption
- Apple cannot access user data
- Data is encrypted in transit and at rest

### Data Minimization
- Only necessary data is synchronized
- No personal identification beyond Apple ID
- Local data validation before sync

## Performance Optimization

### Sync Frequency
- **Foreground**: Immediate sync on data changes
- **Background**: Every 60 seconds if auto-sync enabled
- **App Launch**: Initial sync check
- **Remote Notifications**: Triggered by CloudKit changes

### Batch Processing
- Large datasets processed in 100-record batches
- Background queue processing to avoid UI blocking
- Memory-efficient streaming for large operations

### Change Tokens
- Incremental sync using CloudKit change tokens
- Only modified records are transferred
- Persistent token storage for resume capability

## Monitoring and Debugging

### Sync Status Monitoring
```swift
// Check sync status
let status = CloudKitService.shared.syncStatus

// Monitor sync changes
NotificationCenter.default.addObserver(
    forName: .cloudKitDataChanged,
    object: nil,
    queue: .main
) { _ in
    // Handle sync completion
}
```

### Debug Information
- Console logging with detailed sync operations
- Sync statistics and timing
- Error details and recovery attempts

### User Interface Indicators
- Real-time sync status in Timeline view
- Detailed sync information in Settings
- Error notifications with actionable solutions

## Best Practices

### For Developers
1. Always validate data before sync
2. Handle sync failures gracefully
3. Provide user feedback on sync status
4. Test with poor network conditions
5. Implement proper error recovery

### For Users
1. Ensure iCloud is enabled and signed in
2. Maintain adequate iCloud storage
3. Keep devices updated to latest iOS version
4. Use reliable network connections for sync

## Troubleshooting

### Sync Not Working
1. Check iCloud account status
2. Verify network connectivity
3. Restart app to trigger fresh sync
4. Check iCloud storage availability

### Data Inconsistencies
1. Force manual sync from Settings
2. Check for app updates
3. Clear sync data and re-sync (last resort)

### Performance Issues
1. Reduce sync frequency in poor network conditions
2. Ensure sufficient device storage
3. Close other resource-intensive apps

## Migration and Backup

### Data Migration
- Automatic migration of existing local data to CloudKit
- Backwards compatibility with pre-sync app versions
- Graceful handling of schema changes

### Backup Strategy
- CloudKit serves as primary backup mechanism
- Local storage remains authoritative during sync conflicts
- Export functionality for external backups

## API Reference

### CloudKitService Methods
- `syncNow()`: Trigger immediate sync
- `saveTask(_:)`: Save task to CloudKit
- `deleteTask(_:)`: Delete task from CloudKit
- `enableCloudKitSync()`: Enable sync functionality
- `disableCloudKitSync()`: Disable sync functionality

### Notifications
- `.cloudKitDataChanged`: Fired when sync completes
- `.cloudKitSettingsChanged`: Fired when settings sync completes

### Status Enums
- `.idle`: Ready to sync
- `.syncing`: Sync in progress
- `.success`: Sync completed successfully
- `.error(String)`: Sync failed with error
- `.disabled`: Sync disabled by user