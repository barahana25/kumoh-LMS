/// Foreground checks must not depend on the OS accepting a background job.
Future<void> runForegroundNotificationCheck({
  required Future<void> Function() schedule,
  required Future<void> Function() check,
}) async {
  try {
    await schedule();
  } on Exception {
    // The next foreground tick retries registration independently.
  }
  await check();
}
