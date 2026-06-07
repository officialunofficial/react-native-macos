# Stage B — merge react-native 0.84 into rn-macos fork

Goal: carry `uno/desktop-0.84-wip` (off the green `uno/desktop-0.85` = 0.83 line)
up to **react-native 0.84.1**, on the way to 0.85 / Expo SDK 56.

## Key finding (de-risks the estimate)

The actual `git merge upstream-rn/0.84-stable` (base `a034841`, the point the fork
last synced) produces **58 conflicted files — not the 316 the file-overlap
heuristic predicted.** Hermes V1 is already handled on the 0.83 line, which removes
the biggest 0.84 risk. This is a focused effort (days), not months.

Reproduce:
```
git checkout uno/desktop-0.84-wip
git fetch upstream-rn 0.84-stable --shallow-since=2025-01-01   # upstream-rn = facebook/react-native
git merge --no-commit --no-ff upstream-rn/0.84-stable
```

## Conflict map (58) and resolution strategy

### A. package.json (27) — fork versioning vs upstream 0.84.1
Fork identity to PRESERVE: main pkg `name: react-native-macos`, `version: 1000.0.0`,
`workspace:*` internal deps, `@react-native-macos/*` scope where the fork renamed,
`private: true` on internal satellites, `-main` satellite versions.
- **Version-only hunks (~11, e.g. assets, gradle-plugin, normalize-color, polyfills,
  virtualized-lists, typescript-config, debugger-*, helloworld):** keep OURS
  (`workspace:*` resolves regardless of the version string).
- **Multi-hunk (~16, e.g. react-native(4), rn-tester(3), dev-middleware(3),
  community-cli-plugin, metro-config, babel-*, eslint-*):** 3-way merge — keep fork
  identity/scope/workspace deps, ADOPT upstream's new/bumped deps and
  `files` globs (e.g. `sdks/.hermesv1version`, `hermes-compiler` → upstream pin,
  drop `glob` if upstream did).

### B. Lock/version files (4) — regenerate, don't hand-merge
- `yarn.lock`: `git checkout --theirs` then `yarn install` to regenerate against merged package.jsons.
- `packages/rn-tester/Podfile.lock`: regenerate via `RCT_NEW_ARCH_ENABLED=1 bundle exec pod install`.
- `sdks/.hermesversion`, `.hermesv1version`, `version.properties`, `hermes-utils.rb`:
  take UPSTREAM (0.84 hermes), then re-apply our #2957 selection logic if it diverges.

### C. Native ObjC/ObjC++/Swift (14) — 3-way, preserve `// [macOS]` guards
RCTUtils.{h,mm}, RCTBundleManager.h, CoreModulesPlugins.mm, RCTAccessibilityManager.mm,
RCTDevLoadingView.mm, RCTDevLoadingViewProtocol.h, RCTEnhancedScrollView.mm,
RCTModalHostView.m, Package.swift. Adopt upstream logic, keep every `#if TARGET_OS_OSX`
/ `[macOS]` block. These are the careful ones; build + RNTester-macOS harness must stay green.

### D. JS (7) — straightforward 3-way
TextInput.js, TextInput.flow.js, TouchableWithoutFeedback.js, Pressability.js,
CoreEventTypes.js, NetworkOverlay.js, ios-prebuild/hermes.js. Keep any `// [macOS]` lines.

### E. Tests / project (6)
- `RCTViewTests.m`: keep OURS + re-add our #2955/#2954 macOS focus tests on top of upstream's changes.
- `RCTEventDispatcherTests.m`, `RCTUIManagerTests.m`, `RCTUIManagerScenarioTests.m`,
  `RNTesterIntegrationTests.m`: 3-way; re-apply new-arch skips as needed (see test plan).
- `project.pbxproj` (gitignored): take UPSTREAM's (it adds 0.84 file refs), then re-restore
  macOS targets / re-run pod install. `RNTesterUnitTests.xcscheme`: 3-way.
- `.gitignore`: union both.

## Verification gates (fast → slow)
1. `yarn install` — validates the whole package.json graph + regenerates yarn.lock.
2. `bundle exec pod install` (RCT_NEW_ARCH_ENABLED=1) — regenerates Podfile.lock, integrates.
3. `xcodebuild test -scheme RNTester-macOS -only-testing:RNTester-macOSUnitTests` — the green harness must stay green.
4. Build + launch RNTester-macOS app.

Then update CHANGELOG/version markers to 0.84.1-flavored fork values and commit the merge.
Stage C (0.85) repeats this against `upstream-rn` v0.85.x.
