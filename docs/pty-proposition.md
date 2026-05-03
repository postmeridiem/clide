# PTY on macOS: A New Diagnostic and Resolution Plan

## 1. Executive Summary

Previous attempts to fix the PTY functionality on macOS have failed, even after correcting a deadlock in the Dart code. The core of the problem appears to be a fundamental mismatch in how the C helper (`ptyc`) constructs a control message and how the Dart FFI layer is trying to parse it.

This document proposes a new, systematic plan to diagnose and resolve this issue by focusing on a key unresolved contradiction: the length of the ancillary data message (`cmsg_len`).

## 2. The Unresolved Contradiction

The primary blocker is a discrepancy in the expected length of the `SCM_RIGHTS` control message:

-   **Observed Behavior:** The raw byte dump provided in `docs/macos-pty-problem.md` from the Dart `recvmsg` call shows the `cmsg_len` field as **16 bytes**.
-   **Code Analysis:** An analysis of the POSIX `CMSG_LEN` macro, as used in `ptyc.c`, suggests the length should be **20 bytes** on a 64-bit macOS system.

This contradiction means we cannot be certain about the memory layout of the data we are parsing in Dart. Without resolving this, any attempt to fix the data offset is guesswork.

## 3. Proposed Investigation and Resolution Plan

This plan will definitively resolve the `cmsg_len` discrepancy and lead to a correct implementation.

### Step 1: Instrument `ptyc` to Reveal Ground Truth

The first step is to get definitive data from the source. We will modify `ptyc.c` to log the exact values it's using.

-   **Action:** Add `fprintf(stderr, ...)` statements in `ptyc.c` right before the `sendmsg` call.
-   **Data to Log:**
    1.  The calculated value of `CMSG_LEN(sizeof(int))`.
    2.  The value of `CMSG_SPACE(sizeof(int))`.
    3.  The value of `sizeof(struct cmsghdr)`.
-   **Expected Outcome:** This will give us the "ground truth" of the control message structure as constructed by `ptyc` in the actual build environment, resolving the 16-vs-20-byte mystery.

### Step 2: Correctly Implement the Dart FFI Parser

With the true `cmsg_len` and memory layout confirmed, we can correctly implement the Dart-side parser.

-   **Action:** Modify `lib/src/pty/ffi/scm_rights.dart`.
-   **Logic:**
    -   If the logged `cmsg_len` from Step 1 confirms there is alignment padding (i.e., data starts at offset 16), the `dataOffset` calculation will be updated to `16`.
    -   If the logged data shows no padding (i.e., data starts at offset 12), the `dataOffset` will be confirmed as `12`, and we will know the issue lies elsewhere.
-   **Expected Outcome:** A Dart parser (`recvFd`) that correctly reads the file descriptor from the ancillary data based on empirical evidence, not theoretical calculation.

### Step 3: Ensure Asynchronous Operation

The previously identified deadlock, while not the root cause of this specific failure, is still a critical bug.

-   **Action:** Ensure the fix in `lib/src/pty/session.dart` is applied, where the blocking `scm.recvFd` call is replaced with its asynchronous counterpart, `_recvFdAsync`.
-   **Expected Outcome:** The Dart event loop is not blocked during PTY creation, preventing deadlocks.

### Step 4: Verification

With the above changes in place, we will verify the complete solution.

-   **Action:** Run the existing test suite via `flutter test test/pty/session_test.dart`.
-   **Success Criteria:** All tests in `session_test.dart` must pass, indicating that a PTY can be spawned, its output can be read, and data can be written to it.

This methodical approach replaces guesswork with a data-driven diagnosis, providing a clear and direct path to resolving the long-standing macOS PTY issue.
