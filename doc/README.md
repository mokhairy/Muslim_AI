# Documentation Index

This folder is the handoff set for the current state of the project.

## Read In This Order

1. [current-state.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/current-state.md)
2. [mobile-roadmap.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/mobile-roadmap.md)
3. [conversation-export-2026-04-05.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/conversation-export-2026-04-05.md)
4. [move-to-new-machine.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/move-to-new-machine.md)
5. [shipping-guide.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/shipping-guide.md)

## Files In This Folder

- `current-state.md`
  Explains the current codebase state, runtime configuration, service setup, and open risks.

- `conversation-export-2026-04-05.md`
  A markdown export of the work completed in this session, written as a chronological engineering log.

- `mobile-roadmap.md`
  Tracks the next two mobile phases: local device adhan automation first, then optional smart-speaker targeting.

- `move-to-new-machine.md`
  A practical migration guide for getting this repository running on another computer.

- `shipping-guide.md`
  Recommends the best path to package and deploy this project properly instead of relying on the local workstation setup.

- `launchd/com.mkhairy.muslim-ai.web.plist.example`
  Example user LaunchAgent for the web service.

- `launchd/com.mkhairy.muslim-ai.worker.plist.example`
  Example user LaunchAgent for the prayer automation worker.

## Scope

These docs focus on what was actually changed and validated during this session:

- prayer current-location behavior
- local speaker playback default
- background macOS service setup
- static-file serving under `gunicorn`
- operational commands and portability notes
- mobile roadmap items that are intentionally deferred
