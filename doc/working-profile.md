# Working Profile

This file captures operational assumptions about the repository owner and preferred working style, based only on repository work and prior session history. It is intended to help future agents collaborate efficiently without over-assuming unstable context.

## Product / Ownership Profile

- The repository owner operates like a product owner and implementation lead, not just a feature developer.
- Work typically spans:
  - app code
  - production deployment
  - release engineering
  - store submission
  - branding assets
  - documentation
- The preferred outcome is usually a real implementation with verification, not a speculative plan.

## Working Style

- Prefer direct execution over long discussion.
- Fixes should be carried through:
  - diagnosis
  - code change
  - validation
  - release impact
- Responses should stay concise and operational.
- When something is broken, the expected default is to repair it and verify it if tooling allows.

## Technical Direction

- Active product: `MuslimAI`
- Web stack: Django
- Mobile direction: Flutter
- iOS and Android are both first-class release targets.
- The project is expected to be publicly deployable, not just locally runnable.
- Arabic and Islamic-content correctness matter, not just generic UI behavior.

## Common Infrastructure Context

- GitHub repo: `mokhairy/Muslim_AI`
- Web domain context includes:
  - `muslimai.geointel.ca`
- Deployment work has used Railway.
- Mobile release work has included:
  - Apple App Store
  - Google Play Store preparation

## Stable Assumptions That Are Usually Safe

- The owner prefers implementation help over brainstorming by default.
- The owner is comfortable moving across backend, mobile, deployment, and store-release workflows in one stream of work.
- Shipping quality matters more than prototype shortcuts.
- Documentation and handoff quality matter when changes are substantial.

## Assumptions That Must Be Revalidated

Do not assume the following without checking:

- current device / simulator / emulator availability
- current login state for:
  - Apple
  - Google Play Console
  - GitHub
  - Railway
  - Supabase
  - Stripe
- current deployment health
- current domain routing / DNS state
- current store-review or build-processing state
- current keystore / provisioning / signing availability
- current third-party API behavior

## Collaboration Guidance For Future Agents

- Start with concrete inspection of the codebase and runtime state.
- Prefer verifying live production and release assumptions when they are time-sensitive.
- Keep answers short unless the task genuinely needs depth.
- When blocked by external account access, complete everything that can be done locally first, then clearly isolate the remaining external boundary.
