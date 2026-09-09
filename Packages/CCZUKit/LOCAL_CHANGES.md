# Local CCZUKit dependency

Based on [RayanceKing/CCZUKit](https://github.com/RayanceKing/CCZUKit), version 1.1.3,
revision `504d5ca061a34a187dcd1261f09bb64febc93502`. Original sources and GPL-3.0 license are retained.
This source dependency keeps the request fixes reproducible without publishing a fork.

Local changes:
- Validate teaching HTTP/business responses before decoding; malformed lists throw.
- Reuse one session, coalesce login, and retry only the HTTP request rejected for authentication, once.
- Propagate URLSession cancellation and bound network timeouts.
- Remove automatic training-plan prefetch and generic mutation retries.
- Explicit training-plan refresh bypasses cache and surfaces failures.

Run `swift test --package-path Packages/CCZUKit` for isolated transport/session tests.
No tests authenticate against a real account or submit teaching transactions.
