# Scrollblock — feasibility, acceptance criteria, and implementation plan

Initial assessment: 2026-10-18. Implementation update: 2026-11-15.

## Current implementation status

The copied template is now an experimental Scrollblock iOS 18+ app. Trading screens/data integrations were removed; branding, the single Instagram/Reels row, truthful connection states, and a separate network-test screen were added. A Swift Expo module controls an embedded Network Extension, generated reproducibly through clean prebuild. The existing manual unsigned IPA workflow is preserved and emits `Scrollblock.ipa` in `Scrollblock-unsigned-ipa`. The separate signed workflow now requires a tunnel profile as well as the app profile.

**The primary Reels-blocking feature is NOT complete.** No selective network rule has been established. `native/rules.json` ships empty and unvalidated, so the main switch cannot claim protection. The native path currently supports five-minute DNS observation sessions and exact-host experimental rule enforcement when a validated rule pack is later supplied. It does not inspect encrypted request paths or isolate traffic by app identity.

Observations cover system DNS for `instagram.com` and `cdninstagram.com`, not all Instagram traffic. Scoped DNS is forwarded to Cloudflare over HTTPS after in-app disclosure and confirmation. Up to 128 hostname observations remain in memory and are cleared at session end; sharing is explicit. Unsupported DNS transports, forwarding failures, or capacity limits end the test rather than keeping broken routing active. Broad API/CDN rules and wildcard rules are rejected. These constraints make this a research build, not production protection.

The user has an iPhone 13 Pro Max with Instagram. See [iPhone testing instructions](docs/IPHONE_TESTING.md). Expo Go can preview UI only; the extension needs a signed native build and eligible Network Extension provisioning. The repository does not yet include an Expo development client. No GitHub push, workflow run, signed IPA, TestFlight upload, or device traffic test has been performed by this task.

Verified locally: 12 JavaScript/signing/workflow tests, TypeScript, native parser/policy tests including 4096 malformed inputs, clean iOS prebuild, generated extension dependency/embedding/entitlements/resources, iOS JavaScript export, and an unsigned standalone tunnel-extension device build. A full app build is not verified locally: installed Xcode is 15.2, below Expo SDK 54's 16.1 minimum; the signed workflow needs Xcode 26 and credentials.

The research and production plan below remain as context; implementation details in this status section supersede earlier descriptions of the untouched template.

Accepted scope update: the user confirmed **iOS 18 and later** as the minimum supported range. This supersedes the original iOS 15 requirement. The app and extension deployment targets are now 18.0.

Accepted objective clarification: **stop continued scrolling through newly recommended Reels inside official Instagram**. The plan now targets preventing delivery/playback of new recommendations. Removing the Reels tab and clearing Instagram's cache are not implementation prerequisites. Already downloaded content is recorded as a limitation; it must not be used to excuse continuing delivery of fresh recommendations.

## Recommendation

**Investigate a focused blocker for newly recommended Reels on iOS 18+.** The one-row interface is straightforward. The technical success condition is that continued swiping cannot obtain fresh playable recommendations while blocking is active. Selective network enforcement that preserves the rest of Instagram still needs a physical-device proof before production delivery can be promised.

The clarification removes visual editing and cache deletion from the critical path. The remaining research question is whether observable network signals distinguish recommendation loading or its media sufficiently to stop the endless feed without collateral damage. A direct competitor advertises local-VPN Reels blocking, making a targeted experiment worthwhile; its claim alone does not establish our implementation's effectiveness.

Recommended next investment: a **5–10 engineering-day feasibility investigation**, after resolving the product interpretations below. Production implementation is conditional on passing both technical and deployment gates. More engineering time cannot remove platform restrictions.

Assumed audience: adults using ordinary, unmanaged iPhones and the official Instagram app. No enterprise enrollment, jailbreak, modified Instagram binary, or browser replacement. App Store distribution is the planning baseline because this template already has a store pipeline; personal distribution would not remove encryption, sandbox, or routing restrictions.

## Existing project and documents reviewed

No dedicated summary file was found, including in ignored project files outside dependencies/build outputs. This file establishes the new product summary. Existing history remains in:

- [BUG_REPORT.md](BUG_REPORT.md): order-book audit, implementation outcomes, and device-verification limitations.
- [docs/APP_STORE.md](docs/APP_STORE.md): Stakan identity, signing, CI, and release constraints.
- [docs/PRIVACY_PUBLISHING.md](docs/PRIVACY_PUBLISHING.md): existing financial-app privacy-page workflow.

The original template used Expo `~54.0.37`, React Native `0.81.5`, React `19.1.0`, Expo Router, JSC, and the legacy architecture. Before conversion, `app.json` identified Stakan / `order-book` / `com.softdev.orderbook`. The original screen and `src/market/` implemented an exchange order book; no Network Extension existed before conversion.

The local `ios/` directory exists but is Git-ignored and regenerated in CI. Any future extension must survive clean prebuild through tracked source/configuration. Merely editing the generated Xcode project would lose the work. The original signing script rejected extensions; the conversion now configures exactly the app and tunnel targets with separate profiles.

The instructed [Expo v54 documentation URL](https://docs.expo.dev/versions/v54.0.0/) currently redirects to `latest`, including the checked SDK subpages. To avoid substituting newer APIs, this assessment also read the [SDK 54 documentation source](https://github.com/expo/expo/blob/sdk-54/docs/pages/versions/v54.0.0/index.mdx), [SDK 54 release notes](https://expo.dev/changelog/sdk-54), and installed version-specific native configuration. No dependency upgrades are proposed.

## Acceptance criteria analysis

These translate the request and subsequent clarifications into testable outcomes. Additional proposed tolerances remain subject to agreement.

| ID | Requested behavior | Assessment and test interpretation |
| --- | --- | --- |
| AC1 | One Instagram icon, “Reels” label, and enable/disable toggle | Feasible. One primary row can own the action. First activation still needs system VPN authorization and relevant disclosure. Connecting, active, off, and error must remain distinguishable. |
| AC2 | Blocking works inside official Instagram | Mandatory for this idea. Validate with the real app, not a WebView. A browser-based result does not pass. |
| AC3 | Stop scrolling through newly recommended Reels (clarified objective) | While enabled, repeated swipes must not obtain fresh playable recommendations. The tab, thumbnails, and already downloaded videos may remain; clearing cache or editing Instagram's UI is not required. An unavailable/loading state can satisfy the playback objective only if retries do not resume delivery and other permitted features still work. |
| AC4 | Everything else in Instagram continues normally | Unproven and likely the hardest technical criterion. Test login, feed photos/video, Stories, text/media DMs, voice/video calls, search, profiles, notifications, and uploads. Do not count blocking all Instagram video as success. |
| AC5 | Only Instagram is affected | Literal app-identity routing is unavailable to an ordinary consumer VPN on the targeted iOS versions. Destination-based rules can affect another app or Safari using the same services. A narrower “no observed regressions in a defined test suite” claim would need explicit acceptance. |
| AC6 | Internet remains fast and unchanged | Exact zero overhead is not realistic. Establish quantitative latency, throughput, battery, and reliability budgets. These must include unrelated apps and poor networks. |
| AC7 | Support iOS 18 and later (accepted update) | Compatible with the current Expo/RN floor. Set the app and extension deployment targets to 18.0 during implementation and verify dependencies. iOS 15–17 and last-compatible Instagram clients are outside scope. |
| AC8 | Toggle off restores normal operation | Verify removal/deactivation of this app's active routing/filter behavior, including on-demand reconnect behavior. Do not alter another app's VPN configuration. Existing Instagram failures may require retrying a request. |
| AC9 | Protection works while Scrollblock is closed | Requires an OS-managed native extension, not a React/JavaScript timer. Test host backgrounding, termination, lock/unlock, network changes, extension restarts, and reboot. Never display “active” from a saved toggle alone. |

Remaining scope details for the next phase:

1. Working interpretation: stop algorithmically recommended Reel sequences, including those reached after opening a shared Reel. Preserve deliberate direct-link/DM playback where technically separable; do not silently turn this into an all-video blocker. Record any inability to distinguish these cases in the feasibility result.
2. Preserve the requirement that other apps work normally. Evaluate destination filtering against that outcome, while keeping the distinction from guaranteed per-process routing explicit. If strict process isolation is later required, the documented managed-device restriction remains a blocker.

## Technical blockers and limitations

### 1. Packet access is not decrypted Instagram access

A VPN receives packets, not a semantic event saying “user opened Reels.” With HTTPS, URL paths, query parameters, request bodies, and responses are encrypted. Routing through our own server does not remove the inner encryption. The tunnel might expose destination IPs, timing/size patterns, DNS queries it actually sees, and hostnames where the handshake exposes them; none is automatically a reliable Reels label. [TLS 1.3 specification](https://www.rfc-editor.org/rfc/rfc8446)

HTTP/3 uses QUIC and multiplexed streams; a TCP-only approach is incomplete. Dropping UDP/443 to induce fallback would introduce unrelated behavior changes and still would not decrypt HTTPS. [HTTP/3 specification](https://www.rfc-editor.org/rfc/rfc9114)

There is no verified, stable Reels-only hostname or IP list established by this assessment. Shared API/media infrastructure is a central hypothesis to test, not a newly measured Instagram traffic fact. Broad Instagram/Meta CDN blocks risk breaking permitted media or other Meta services. DNS cannot distinguish URL paths on the same hostname; AdGuard documents the same fundamental limitation for first-party advertising. [AdGuard Home FAQ](https://github.com/AdguardTeam/AdGuardHome/wiki/FAQ)

Traffic-size or timing classification is probabilistic and vulnerable to prefetching, connection reuse, account experiments, and network conditions. Encrypted DNS or hidden handshake names may reduce available signals further; do not assume every Instagram build uses the same transports.

Installing a root certificate and intercepting TLS would change the onboarding and privacy model. Certificate pinning can reject interception; this investigation did not test Instagram's current pinning behavior. A product requiring users to modify Instagram or bypass its trust checks is outside the requested scope. A successful decrypted lab trace would not prove a consumer VPN can enforce the same rule.

### 2. Instagram-only routing is a platform boundary

Apple documents iOS per-app VPN configuration through MDM-managed apps. The development-only `NETestAppMapping` mechanism does not work in distribution-signed builds. Ordinary destination routes select IPs, not an arbitrary installed Instagram process. Do not mistake a development demonstration for a distributable solution. [NETunnelProviderManager](https://developer.apple.com/documentation/networkextension/netunnelprovidermanager)

Device-wide routing with selective filtering and strict app-specific routing are different promises. A network extension also cannot edit another app's view hierarchy or erase its local caches; preventing future delivery cannot guarantee immediate invisibility.

**Why not clear the cache when enabling the toggle?** Scrollblock can clear its own storage, but Instagram's disk cache and in-memory video buffers belong to Instagram. iOS sandboxing prevents another app from modifying that private data; VPN authorization does not grant access. There is no supported general cross-app cache-clearing API for this toggle. Clearing a tunnel's DNS/connection state would not delete downloaded videos. Therefore cached playback remains a limitation even with an iOS 18 minimum, and must be reported separately in acceptance tests. [Apple runtime sandbox security](https://support.apple.com/en-au/guide/security/sec15bfe098e/web)

### 3. A local “special VPN” has a deployment obstacle

Apple's TN3120 identifies packet tunnels used as local content filters, or to claim traffic and proxy it elsewhere, as unsupported uses. Therefore a local packet-processing/proxy engine is an **experimental architecture with an unresolved deployment blocker**, not the default production recommendation. A real remote VPN is a different architecture with server costs and latency, and still cannot read encrypted Reels requests. [Apple TN3120](https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers)

App Review guideline 5.4 requires organization enrollment for apps offering VPN services and prescribes disclosures and data-use restrictions. It also provides a route for approved content-blocking/security providers. Confirm the classification and permitted architecture for this product; neither an entitlement nor an existing competitor guarantees approval. Do not assume the current developer account meets these conditions. [App Review guidelines](https://developer.apple.com/app-store/review/guidelines/#vpn-apps)

### 4. Alternative Apple APIs do not solve the iOS 18 consumer baseline

- Content filter providers have deployment restrictions. Apple's documented Screen Time exception applies to authorized child devices; adult individual authorization does not unlock this general network filtering capability. Managed/supervised deployments are a different audience.
- The newer URL-filter provider starts at iOS 26, so it cannot be the baseline for iOS 18. It could be investigated as an optional newer-OS path, but cannot replace working baseline behavior. Automatic coverage is tied to Apple networking APIs; other stacks need app participation. It is not proof that Instagram's relevant requests are filterable.
- Screen Time application shielding blocks applications rather than selectively deleting their Reels UI. It can support an alternative whole-app restriction product, not satisfy the current ACs.

Sources: [Apple deployment matrix, TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment), [Apple engineer clarification](https://developer.apple.com/forums/thread/715226), [WWDC25 URL-filter coverage](https://developer.apple.com/videos/play/wwdc2025/234/).

### 5. Reliability and performance remain substantial work

A selective blocker must account for existing connections, DNS caching, IPv4/IPv6, NAT64, cellular/Wi-Fi changes, preloaded media, retries, and remote endpoint changes. A bad rule can leave Instagram repeatedly retrying, consuming battery while appearing broken.

Do not promise simultaneous compatibility with arbitrary VPN apps. Apple limits enabled enterprise VPN configurations; conflicts depend on configuration and routing. Detect and explain unsupported combinations. [VPN configuration model](https://developer.apple.com/documentation/networkextension/netunnelprovidermanager)

Prefer preserving connectivity when the experimental classifier fails: surface protection as unavailable and allow traffic. This proposed fail-open policy trades blocking persistence for the user's fast, working internet requirement; it needs agreement before implementation. An aggressive fail-closed tunnel would contradict that priority during failures.

## iOS compatibility

| Version | Current shell | Product constraint |
| --- | --- | --- |
| iOS 15–17 | Outside accepted product scope | No compatibility commitment or legacy Instagram test lane. |
| iOS 18.x | Supported baseline | Test physical devices; the routing, encryption, and UI limitations remain. |
| iOS 26+ | Included in the advertised 18+ range | Validate current OS releases separately. New APIs do not backport; optional enhancements cannot substitute for the iOS 18 baseline. |

Current configuration evidence: local `ios/Podfile`, generated project deployment targets, and `node_modules/react-native/scripts/cocoapods/helpers.rb` use 15.1. This is the existing template floor, not the new product requirement. [Instagram's current App Store listing](https://apps.apple.com/us/app/instagram/id389801252) requires iOS 16.3 or later, which introduces no minimum-OS conflict with the accepted 18+ scope.

Building with a current Apple SDK is separate from the minimum runtime OS. Existing release notes describe an Xcode 26 pipeline preserving the old 15.1 target; implementation must update generated app/extension targets to 18.0 and perform a real extension-capable build validation. Historic local Xcode limitations in the old audit were not rechecked during this planning task.

## Similar applications and approaches

These are public developer claims or documented mechanisms, not apps installed and independently benchmarked in this investigation.

| Product/context | Public evidence | Relevance |
| --- | --- | --- |
| [SocialLite](https://apps.apple.com/pl/app/sociallite-block-reels-shorts/id6757661674) | The supplied reference; its release notes describe native-app shielding and redirection to SocialLite. Current listing requires iOS 17+. | Useful UX reference. Consistent with the user's browser-replacement description; not evidence of packet-level native Reels filtering. |
| [Nima: Block Reels & FYP](https://apps.apple.com/nz/app/nima-block-reels-fyp/id6790122342) | Explicitly advertises on-device local-VPN detection/blocking of distracting connections while retaining useful features. Requires iOS 17+. | Closest claimed competitor; its OS minimum fits the revised scope. Public material does not disclose a classifier or prove selectivity or performance. Prioritize hands-on validation. |
| [WallHabit](https://wallhabit.com/blog/disable-instagram-reels-on-ios/) | Developer advertises native-app Reels detection and backing users out of that screen. | Native-app behavior exists as a product claim, but the article does not establish VPN/network filtering. Do not infer its implementation from marketing or use it as proof of this architecture. |
| [ScrollGuard](https://scrollguard.app/blog/how-to-block-instagram-reels-iphone) | Developer describes Shortcuts redirection to a filtered web app. | Browser-controlled UI can hide elements; this changes the user's required interaction model. |
| [AdGuard for iOS](https://adguard.com/en/blog/what-is-dns-filtering.html) / [AdGuard Home FAQ](https://github.com/AdguardTeam/AdGuardHome/wiki/FAQ) | DNS/domain filtering and documented same-domain limitations. | Relevant networking precedent, not evidence of reliable feature-level Reels blocking. |

Research conclusion: a comparable VPN-based claim does exist. That weakens any blanket claim that no one attempts this, but it does not resolve Apple's documented constraints or establish the complete requested behavior. Marketing descriptions are insufficient for an implementation commitment.

## Production implementation plan — remaining work is conditional on feasibility

### Phase 0 — choose the testable contract (0.5–1 day)

Use the settled iOS 18+ minimum and newly recommended Reels objective. Record the working interpretation for direct-link/DM playback and app isolation above. Confirm audience and distribution, the Apple account type, physical-device availability, and whether another VPN must coexist. Define how failure should affect internet access. Cache deletion and visual removal do not gate the experiment.

Deliverable: an agreed AC table and explicit unsupported cases. Do not silently substitute a browser, whole-app block, or all-video block.

### Phase 1 — feasibility investigation (5–10 engineering days)

1. Reproduce the closest competitor's advertised behavior on iOS 18 and record permissions/setup, playback outcomes, effects on DMs/Stories, VPN conflicts, and latency. Keep this distinct from our own implementation proof; no purchase or install was performed during this task.
2. Capture consented test-device network metadata during labeled Instagram actions, with unrelated apps quiet initially and then active. Use stock Instagram, controlled test accounts, and ordinary transports. Record exact iOS/app builds, accounts, networks, and cache state. Do not collect credentials or publish raw personal traffic.
3. Compare cold and warm sessions across Reels, feed video, Stories, DMs and calls. First investigate whether recommendation retrieval/pagination has a distinguishable network signal: stopping replenishment may preserve more functionality than denying media delivery. This is a hypothesis, not a known exposed endpoint. If only media signals are distinguishable, measure their collateral effects explicitly. Seek counterexamples before writing rules, and test another account and network not used to derive them.
4. Validate candidate rules at a controlled test network first, if possible. Then test only the minimum native enforcement experiment needed. A lab router result alone is insufficient for cellular or App Store feasibility.
5. Resolve the supported API/deployment route with Apple documentation and, if needed, an Apple technical/support inquiry prepared for the owner. Do not send inquiries or treat a conceptual response as App Review preapproval without separate authorization.
6. Produce a measured decision report: evidence for separation, collateral failures, cache leakage, platform/deployment result, performance, and a proposed architecture or stop decision.

**Go criteria:** repeated swipes, retrying, reopening Instagram, and network changes do not replenish the feed with newly playable recommendations on held-out accounts/networks; permitted features remain functional; cached playback is measured separately; and there is a viable distribution architecture. No root certificate, modified Instagram, or developer-only routing shortcut may be necessary for the consumer result.

**Stop criteria:** recommendations continue replenishing under the tested rules; rules require denying shared media essential to permitted features; signals fail across clients/accounts; distribution relies on unsupported mechanisms without an acceptable route; or performance budgets cannot be met. Existing cached videos alone are not a failure, but new deliveries must not be mislabeled as cache. A successful experiment is evidence for its tested scope, not a permanent guarantee against Instagram changes.

### Phase 2 — native architecture and template conversion, only after a pass

Use Expo SDK 54 for the small app shell with an iOS 18.0 deployment target. Keep packet/connection handling in Swift/native code, outside React and the JavaScript bridge. A local Expo module can expose permission/setup, enable/disable, actual status, and limited diagnostics; it does not by itself provide an OS-managed extension.

If a supported VPN architecture is established, the candidate components are a native controller using `NETunnelProviderManager`, a separately signed provider extension, minimal shared configuration through an App Group, and native connection-status events. If research selects DNS settings, managed content filtering, or a remote tunnel instead, update the product contract and architecture first. Do not implement a local packet proxy merely because it is technically possible.

Proposed future source responsibilities:

- `app/index.tsx`: replace the trading screen with the single Instagram / Reels / switch row, accessible status, and concise errors.
- `modules/`: local native bridge, including status synchronization after foregrounding.
- Tracked native-extension source plus `plugins/`: reproducible targets, embedding, entitlements, App Group, and deployment settings through clean prebuild.
- Native filtering/rule component: only the classifier validated in Phase 1; bounded work and memory, versioned rules, rollback, no content logging.
- `app.json` and assets: new product identity and branding; decide whether to use a new bundle ID/listing before repurposing Stakan.
- `src/market/`, trading components/tests: retire only during the later implementation; keep general build verification where useful.

Preserve current SDK/runtime choices unless a measured compatibility issue requires a separate change. Use SDK-matched tooling when implementation starts. A custom native development build is required; Expo Go or a web preview cannot validate this feature. The extension should remain small and independent of the React Native runtime.

### Phase 3 — extension signing, lifecycle, and release readiness

Replace the current single-app signing assumption with explicit app and extension IDs/profiles, required capabilities, App Group configuration, and export mappings. Validate entitlements in every embedded bundle and after clean prebuild. Preserve rejection of unexpected extra targets.

Implement cancellation/error handling, user-denied/revoked permission, OS status synchronization, network transitions, and clear failure reporting. Do not confuse “VPN connected” with demonstrated Reels protection. Review on-demand recovery and disconnect behavior so turning the toggle off stays off.

Update product-specific privacy/support pages and store disclosures for actual network processing. Remove financial-app claims from the eventual product. Confirm Instagram icon usage and avoid implied affiliation. Prepare review notes explaining the architecture and limitations accurately; no approval outcome is guaranteed.

### Phase 4 — device acceptance and release decision

Use physical iOS 18.x devices and current supported OS releases, recording exact Instagram builds. Include older iPhone hardware that supports iOS 18 to measure constrained-device performance. Exercise Wi-Fi, cellular, IPv6/NAT64, slow/lossy networks, captive portals, cache states, reboot, locking, extension restart, and other-VPN combinations.

Proposed initial research budgets, subject to agreement and measured variance:

| Dimension | Proposed acceptance evidence |
| --- | --- |
| Reels | Zero fresh playable recommendations delivered while protection is active in the agreed entry-point test set. At least 100 swipe/retry attempts per supported client/OS combination across multiple sessions, including reopening and network changes. Record the number/duration of already downloaded Reels separately and correlate playback with network observations; do not assume every successful playback is cached. Deliberate direct-link playback is evaluated separately. |
| Permitted Instagram actions | All scripted login, messaging, media, Stories, search, notification, call, and upload cases pass; any reproducible regression blocks release. |
| Other apps | No reproducible failures in Safari (including Instagram web), other Meta apps, messaging, video, calls, and representative downloads. This is test coverage, not a mathematical app-isolation guarantee. |
| Performance | Paired enabled/disabled trials: p95 additional request latency ≤20 ms and sustained throughput loss ≤5% on stable networks. Report cellular variability and remote-tunnel impact separately. |
| Battery/reliability | No repeatable excess drain above an agreed budget; initial target ≤2 percentage points over a controlled 8-hour run. A 24-hour mixed-use soak has no persistent connectivity loss. Repeat noisy measurements. |
| Toggle/lifecycle | Truthful state after permission rejection, backgrounding, external disconnect, and restart; ordinary off/on transition target ≤5 seconds on a healthy connection. |

None of these measurements has been run. Passing the finite suite supports a scoped release claim only. Ongoing testing after Instagram/server-side changes is part of operating this product.

## Complexity and effort estimate

Planning ranges for one experienced iOS/Network Extension engineer with React Native familiarity, available devices and account access. These are engineering estimates, not vendor quotes or promises.

| Work | Complexity | Estimated effort |
| --- | --- | --- |
| Contract and distribution clarification | Medium | 0.5–1 day plus external response time |
| Feasibility experiment and decision | Very high uncertainty | 5–10 engineering days, strictly time-boxed |
| One-row UI and template cleanup | Low | 1–3 days |
| Native controller, extension/configuration and signing CI | High | 2–3 weeks |
| Validated classifier integration, recovery, performance | Very high | 3–5 weeks |
| Cross-device QA, privacy/store preparation, stabilization | High | 2–4 weeks |

**Conditional production range: roughly 8–15 engineering weeks total, including discovery**, assuming a viable classifier and acceptable architecture already emerge from the experiment. The iOS 18 minimum removes legacy-client work, but the core research and native networking dominate this estimate, so there is not yet evidence for a narrower range. External Apple response/review time, obtaining test devices, backend operations if a real remote VPN is chosen, and ongoing rule maintenance are additional. A complex new packet-processing stack could exceed this range and requires re-estimation.

The earlier visual-removal/cache-clearing requirement has been superseded by the newly recommended Reels objective. That makes a focused experiment meaningful, but does not establish a stable classifier or supported distribution architecture. The estimate remains conditional until those two questions are resolved; guaranteed per-process isolation and literally zero overhead are not established capabilities.

If feasibility fails, document that result before choosing another product: a filtered browser can control its UI; whole-app Screen Time restrictions change the blocking scope; newer-iOS URL filtering or managed deployment change compatibility/audience. None is an automatic substitute for the requested idea.

## Initial assessment record (2026-10-18)

Reviewed existing audit/release notes and relevant project/native configuration; checked Expo SDK 54 evidence, Apple networking/deployment rules, protocol limitations, and public competing-product descriptions. Created this summary only. No application, native, dependency, configuration, or CI code changed. No builds, traffic captures, competitor installs, purchases, device tests, external messages, or store submissions were performed.
