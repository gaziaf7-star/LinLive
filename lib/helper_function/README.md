# Call Rejection Widget

## Overview
The `CallRejectionWidget` provides call management functionality for audio live streams, allowing broadcasters and callers to manage call states.

## Features

### For Broadcasters
- **Caller List Management**: View all active callers in a bottom sheet
- **Audio Control**: Toggle audio on/off for individual callers
- **Video Control**: Toggle video on/off for individual callers  
- **Call Cancellation**: Cancel any caller's call with confirmation

### For Callers
- **Call Cancellation**: Cancel their own call with confirmation dialog
- **Status Awareness**: Only shows cancel button if user is in caller list

### For Viewers
- **No Interface**: Viewers who are not callers see no controls

## Usage

```dart
CallRejectionWidget(
  isBroadcaster: widget.isBroadcaster,
  streamId: streamInfo['id'] ?? 0,
  userId: liveController.authController.userProfile.value?.user?.id?.toInt() ?? 0,
  isUserInCallerList: true, // Implement logic to check actual caller status
)
```

## Parameters

- `isBroadcaster`: Boolean indicating if current user is the broadcaster
- `streamId`: ID of the current livestream
- `userId`: Current user's ID
- `isUserInCallerList`: Boolean indicating if user is in the caller list

## API Integration

The widget uses the `tryToRejectCall` method from `LivestreamController` which calls the `rejectCall` API endpoint:

```dart
controller.tryToRejectCall(
  streamId: streamId,
  userId: userId,
);
```

## UI Components

### Broadcaster View
- Blue button labeled "Caller List"
- Opens bottom sheet with caller management options

### Caller View  
- Red button labeled "Cancel Call"
- Shows confirmation dialog before cancelling

### Bottom Sheet (Broadcaster)
- List of all active callers
- Each caller has:
  - Profile avatar and name
  - Audio toggle button (green)
  - Video toggle button (blue)
  - Cancel call button (red)

## Error Handling

- Network errors are handled gracefully
- Success/error messages are shown via snackbars
- Confirmation dialogs prevent accidental actions

## Dependencies

- GetX for state management and navigation
- Material Design components
- LivestreamController for API calls