Eirinchan is vichan rewritten in Elixir/Phoenix with PostgreSQL as the primary datastore.

Implementation Plan

1. Define compatibility scope and freeze behavior
- Target parity with the currently deployed vichan behavior in local VPS (posting, reports, moderation, feedback, static board rendering, API output).
- Create a compatibility matrix of endpoints, templates, moderation actions, and config keys.
- Mark features as must-have, deferred, or intentionally dropped.

2. Establish Phoenix architecture and project boundaries
- Create Phoenix umbrella-like boundaries within one app: Web (controllers/live), Domain (contexts), Infra (repos/storage/queue).
- Split contexts by capability: Boards, Posts, Media, Moderation, Reports, Feedback, Themes, Search, Auth, Build.
- Keep all request-level orchestration in controllers/live modules; keep business rules in contexts.

3. PostgreSQL schema design and migration strategy
- Design normalized core tables: boards, posts, post_files, reports, feedback, feedback_comments, bans, mod_users, mod_logs, cites, settings.
- Replace per-board SQL tables with partitioning by board_id where helpful.
- Add migration scripts and backfill tools from existing MySQL schema and JSON file payloads.

4. Posting pipeline implementation
- Implement form submission pipeline equivalent to post.php behavior: captcha, anti-spam, thread checks, file checks, EXIF/orientation handling, filters, flood checks, tripcode/capcode, cites, insert, rebuild triggers.
- Preserve feature flags and board-specific overrides with deterministic precedence.
- Implement identical user_flag/multiple_flags and country-flag modifier behavior.

5. Media pipeline and storage abstraction
- Build a media service abstraction with local FS first, optional object storage adapter later.
- Implement hash-based duplicate checks, thumbnail generation, spoiler handling, EXIF stripping and orientation controls.
- Preserve multiple upload semantics and metadata extraction paths.

6. Rendering and build pipeline
- Recreate thread/index/catalog generation with explicit jobs and cache invalidation.
- Implement static artifact output compatible with current URL layout where possible.
- Provide JSON API endpoints matching current data contracts.

7. Moderation and authentication
- Implement moderator auth, role/board-scoped permissions, secure action tokens, and mod logs.
- Recreate report queue and feedback queue behaviors including unread state, mark-as-read, delete, and comments.
- Keep IP visibility controls and permission checks consistent.

8. Themes and extensibility
- Implement a theme registry with install/configure/rebuild lifecycle.
- Port current custom themes (including Feedback and IpAccessAuth behavior) as Phoenix-rendered modules.
- Add extension hooks equivalent to vichan events where feasible.

9. Anti-abuse, security, and observability
- Port DNSBL/flood/rate-limit checks and hidden-input anti-spam behavior.
- Add structured logs, telemetry, audit trails, and security-focused defaults.
- Add explicit config toggles for risky behavior and production hardening.

10. Testing and verification
- Build integration tests for full pipelines: post, report, feedback submission and moderation actions.
- Add snapshot/contract tests for rendered thread/index/catalog and API JSON.
- Add migration validation tests comparing sample data before and after conversion.

11. Operational tooling and deployment
- Add admin tasks (rebuild, migrate, maintenance cleanup, queue workers).
- Provide Docker-based local dev and production deployment guides.
- Add rollback-safe DB migrations and health checks.

12. Incremental rollout
- Run eirinchan alongside vichan in shadow mode for read-only verification first.
- Enable controlled write traffic for selected boards.
- Cut over board-by-board once parity metrics and moderation workflows are validated.
