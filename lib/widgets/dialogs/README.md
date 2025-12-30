# Cancel Trip Dialog

A reusable dialog widget that displays a confirmation popup when users want to cancel a trip.

## Features

- Matches the app's design system with consistent colors and styling
- Shield icon with warning message
- Two action buttons: "No, Go Back" and "Yes, Cancel Trip"
- Customizable callbacks for confirm and cancel actions
- Static method for easy usage

## Usage

### Basic Usage

```dart
import '../widgets/widgets.dart';

// Show the dialog and handle the result
void _showCancelDialog() {
  CancelTripDialog.show(context).then((confirmed) {
    if (confirmed == true) {
      // User confirmed cancellation
      _handleTripCancellation();
    }
    // If confirmed is false or null, user cancelled
  });
}
```

### With Custom Callbacks

```dart
void _showCancelDialog() {
  CancelTripDialog.show(
    context,
    onConfirm: () {
      Navigator.of(context).pop();
      _handleTripCancellation();
    },
    onCancel: () {
      Navigator.of(context).pop();
      // Optional: Handle cancel action
    },
  );
}
```

### Direct Widget Usage

```dart
showDialog(
  context: context,
  builder: (context) => CancelTripDialog(
    onConfirm: () {
      Navigator.of(context).pop(true);
      _cancelTrip();
    },
    onCancel: () {
      Navigator.of(context).pop(false);
    },
  ),
);
```

## Integration Example

Here's how to integrate it into a screen with a cancel button:

```dart
ElevatedButton(
  onPressed: () => _showCancelTripDialog(),
  child: Text('Cancel Trip'),
)

void _showCancelTripDialog() {
  CancelTripDialog.show(context).then((confirmed) {
    if (confirmed == true) {
      // Remove trip from list
      setState(() {
        trips.removeWhere((trip) => trip.id == currentTripId);
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  });
}
```

## Styling

The dialog uses the app's color scheme:
- Background: `Color(0xFFE8E8E8)` (light gray)
- Text: `Color(0xFF424242)` (dark gray)
- Confirm button: `Color(0xFF4CAF50)` (green)
- Shield icon background: `Color(0xFF424242)` (dark gray)

## Parameters

- `onConfirm`: Optional callback when user confirms cancellation
- `onCancel`: Optional callback when user cancels the action

## Return Value

When using the static `show` method, it returns a `Future<bool?>`:
- `true`: User confirmed the cancellation
- `false`: User cancelled the action
- `null`: Dialog was dismissed without action