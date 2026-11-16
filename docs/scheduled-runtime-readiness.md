# Scheduled latest-runtime validation

Scheduled WebView runs first perform a read-only readiness check. A missing or
still-draft mirror, or a fork source branch still catching up, is **deferred**:
the `verify` job is skipped, no package is uploaded and no successful-validation
marker is written. A successful readiness job is not package/browser acceptance.
Push and manual runs retain the existing strict synchronization/build behavior.

A missing/draft release lasting two hours from upstream publication produces one
failed readiness run per release tag. Before deliberately failing, the workflow
saves a per-tag alert marker using the existing Actions cache facility. Subsequent
waiting schedules for that tag report deferral rather than repeating the alert.
Mere source-branch lag is always deferred, not aged using an old release's
publication time; this gate does not alert on persistent source-only lag.
A different tag gets its own marker. Recovery runs validation even if an old alert
marker exists. API/auth/rate-limit errors and published-asset/tag integrity errors
are never converted into waiting or suppressed by the marker. Real package,
rollback, compatibility and browser failures remain unchanged.

This is best-effort deduplication, not permanent storage: GitHub cache eviction
or deletion can cause another alert for the same tag. Cache failures are not
silenced. No extra token, repository permission or email setting is required.

Tests: `python tools/test_reawebapi_schedule_gate.py`. The new gate does not
replace the full provenance/digest checks performed by the existing build tools,
or native REAPER acceptance. No package can be accepted solely by readiness.
