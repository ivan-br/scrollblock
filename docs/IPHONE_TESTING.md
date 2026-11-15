# Test Scrollblock on your iPhone 13 Pro Max

Updated 2026-11-15. Requires iOS 18 or later and the official Instagram app.

This is an experimental network-test build, not a working Reels blocker. The Reels switch intentionally stays unavailable because no selective rule has been validated. The test collects limited DNS evidence to determine whether a useful rule exists. A DNS capture may be insufficient if Instagram shares domains across features or bypasses system DNS.

## 1. Build using the existing artifact workflow

1. Commit and push the Scrollblock changes to your GitHub repository. The workflow must exist on the repository's default branch to appear as a manually runnable action; select your implementation branch when running it.
2. Open **Actions → Build iOS IPA → Run workflow**.
3. Wait for the build to finish. Open the run and download **Scrollblock-unsigned-ipa** under Artifacts.
4. Unzip the downloaded artifact to obtain `Scrollblock.ipa`.

The process is unchanged: dependencies → tests → clean Expo prebuild → Pods → unsigned Release device build → package `Payload` → upload IPA artifact. The new verifier checks that `ScrollblockTunnel.appex` is embedded and both bundles target iOS 18.

## 2. Sign and install

The artifact is **unsigned**. It cannot be installed by opening it in Files or Expo Go. A signing/install tool must sign both bundles with valid profiles that authorize `com.apple.developer.networking.networkextension = [packet-tunnel-provider]`:

- App: `com.softdev.scrollblock`
- Extension: `com.softdev.scrollblock.tunnel`

Use an eligible Apple Developer team with Network Extension capability. Do not assume free Apple-ID sideloading can grant this capability. A tool that strips the extension or restricted entitlements can leave the screen working while the VPN fails. If a signing tool rewrites identifiers, its provider identifier and extension identity must remain consistent.

Alternatively use the existing **Build iOS App Store** workflow after configuring both distribution profiles as described in [APP_STORE.md](APP_STORE.md), then enable its optional TestFlight upload and install through TestFlight. An App Store-signed IPA is distributed through Apple, not by directly opening the artifact on the phone.

Expo Go can only preview the interface. The repository does not currently include `expo-dev-client` or an EAS development-build profile. A custom development build is a separate installation path; `npx expo start --dev-client` alone does not build or sign the extension.

## 3. Run one short test

1. Record your iOS version and Instagram version. Start on Wi-Fi; temporarily disconnect other VPNs for this test.
2. Open **Scrollblock → Network test & privacy**. Read the disclosure: scoped Instagram DNS queries are forwarded to Cloudflare over HTTPS. Hostname observations stay in memory; they are exported only when you share them.
3. Tap **Start five-minute test**, confirm, and allow iOS to add the VPN configuration.
4. Wait for **Test running · Reels are not blocked**. If this does not appear, use **Refresh connection status** and report the exact error instead of continuing.
5. Choose **baseline**, then remain outside Instagram for about 15 seconds.
6. Choose **reels**, switch to Instagram and swipe through 10–20 newly recommended Reels for 30–45 seconds.
7. Return to Scrollblock and tap **Refresh observations**. Choose **Share observations…** and save/send the JSON text before stopping. You can paste the JSON into this chat.
8. Tap **Stop test**. Check that Instagram and ordinary browsing still work.

Repeat with **stories**, **messages**, and **feed**, using a separate session for each and exercising the corresponding feature for 30–45 seconds. Repeat on cellular afterward. Do not share message contents, account passwords, tokens, or screenshots containing private conversations.

The extension clears its observations when stopped or after five minutes; share before that happens. The screen displays only the latest 30 observations, while export includes up to 128. Phase labels describe what you intended to test, not verified app/process attribution.

## 4. Report the result

Provide iOS/Instagram versions, Wi-Fi or cellular, the selected phase, exported observations, and whether Instagram or other apps slowed down or failed. Empty observations can result from DNS caching or a different networking path; they do not demonstrate blocking. If the test disconnects early, report when and what you were doing.

The next engineering step is comparing Reels against permitted activity and then testing any candidate rule on-device. Do not enable broad blocks for `i.instagram.com`, `instagram.com`, or shared media infrastructure; breaking all video is not success.

## Recovery

Tap **Stop test** in Scrollblock. If needed, disconnect Scrollblock under **Settings → General → VPN & Device Management → VPN**. There is no on-demand reconnection. Removing the Scrollblock VPN configuration revokes its setup. No certificate, Instagram modification, or cache deletion is required by this test.

References: [Expo development builds](https://docs.expo.dev/develop/development-builds/introduction/), [Apple supported capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios/), [TestFlight internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).
