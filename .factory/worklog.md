# Task 900: re-land PR #17
- Goal: #17 back on main, main green.
- Finding: #17 (5ccc235) is still on main; revert #19 never merged. The iOS Build failure was a flaky share-sheet UI test (MeetingExportUITests.testCopyActionsSurviveTranscriptDismissalAndReopening). Re-run of run 38320031464 passed every job.
- Context facts used: none applied (no docs/MEMORY.md).
