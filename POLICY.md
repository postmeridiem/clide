# clide Policy

This document governs what clide is allowed to do at runtime, what it's allowed to depend on, and how contributors — human and agent — introduce code into the project. It is binding on all contributors. When in doubt, stop and ask.

Rationale for specific architectural choices referenced here and in code comments (the D-### markers) lives in `decisions/`. This document sets the rules; `decisions/` records why the rules produced the code they did in a given case. If the two ever disagree, the rule in this document wins until the document itself is changed.

## Why this document exists

clide's security model rests on a simple claim: the behavior of the app on a user's machine is fully determined by the signed release artifact and the files in this repository at the time of that release. Every file the app reads, every binary it executes, and every wasm component it instantiates on the default launch path was present, reviewed, and pinned when we built the release.

The moment that claim stops being true — the moment the app fetches something from the network that wasn't audited at build time — the entire sandboxing and trust story collapses. It doesn't matter how good the capability model around wasm components is if the components themselves are downloaded from the internet at first launch.

This policy exists to keep that claim true.

## The core rule: no network on the default launch path

clide does not perform network I/O during app startup, library initialization, or first use of any API, unless the user has explicitly asked for it.

"Explicitly asked for it" means the user pressed a button, ran a command, or otherwise took an action whose stated purpose is to cause a network fetch. Opening the app is not such an action. Opening a file is not such an action. Typing in a buffer is not such an action.

### What this prohibits

- Libraries that download their own native binaries on first import or first call (the `wasm_run` pattern).
- Language servers, formatters, or grammars that auto-install from the network when a file of that language is opened.
- Fonts, icons, or assets fetched from a CDN rather than bundled.
- Telemetry, crash reporting, or analytics that connect on startup regardless of user consent.
- Auto-update checks that run without the user asking.
- Any transitive dependency behavior that does the above, regardless of whether our code triggered it.

### What this allows, grudgingly

Signed, pinned fetches are permitted for a narrow set of cases where the alternative is materially worse. To qualify, all of the following must be true:

1. The artifact URL is hardcoded in the repository, not constructed at runtime.
2. The artifact is verified against a cryptographic hash committed to the repository, or a signature verified against a public key committed to the repository.
3. The fetch is cached; subsequent launches do not re-fetch.
4. Fetch failure produces a clear error, not a silent degradation.
5. The first launch after install can complete its primary function without the fetch succeeding. If the fetch is required for the app to work at all, this is not a "grudging allowance" case — vendor it instead.

If you cannot satisfy all five, the answer is vendoring or explicit user action, not a signed fetch.

### What this allows freely

Network I/O is unrestricted when the user has explicitly initiated it. Examples:

- "Install the Rust grammar" — fetches on button press, fine.
- Cloning a repository the user typed the URL of.
- Connecting to an LSP server the user configured.
- Any feature whose stated purpose is to talk to the network (HTTP client, git, SSH).

The rule is about the *default* path, not about forbidding network ever.

## Dependencies: zero by design

clide's default answer to "should we add a dependency" is **no**. Every dependency is a liability — code we didn't write, running in our users' address space, that we are nonetheless responsible for. The right number of dependencies is the number that makes clide meaningfully better than writing the code ourselves, and that number is small.

This is not a preference. It is the project's architectural stance, documented in `CLAUDE.md` as "no dep graph by design, exact-pinned, CVE-checked, audited." Every dependency that exists in clide is there because someone argued for it, someone reviewed the argument, and the answer was yes. Dependencies do not accumulate by accident.

### What "no dep graph by design" means in practice

- **Prefer writing it.** A 100-line utility written in-repo is cheaper than a 100-line dependency, even though the dependency looks free. We own the code either way; the dependency just hides that fact behind a pub.dev page.
- **Prefer the standard library.** Dart, Flutter, and Rust all have large standard libraries. Reach for them before reaching for a package. "There's a package that does this" is not a reason; "the standard library cannot do this reasonably" is.
- **Prefer inlining over depending.** If a package is small and does one thing we need, copy the relevant code (with attribution) rather than taking on the dependency. License permitting, this is usually the right call for utilities under a few hundred lines.
- **Prefer vendoring over fetching.** When a dependency is unavoidable and small enough to own, fork it into the repo and maintain it ourselves. The dep graph stops at our fence.
- **Reject deep trees.** A direct dependency that itself has fifteen transitive dependencies is fifteen dependencies we are taking on, not one. Evaluate the whole subtree, not just the top.
- **Format engines clear the bar.** Packages that parse or render external file formats (SVG, markdown, HTML, terminal escapes, tree-sitter grammars) are adoptable — they are not shortcuts for lazy coding but maintained renderers for specs we didn't write. The distinction: UI chrome (panels, tabs, canvas, layout) we own; someone else's file format we adopt and sandbox. See D-058.

### Every dependency is audited

For every dependency that does land, the following must be true and documented:

- **Exact-pinned.** `1.2.3`, never `^1.2.3` or `>=1.2.0 <2.0.0`. Lockfiles are committed. Updates are deliberate, reviewed PRs, not automatic.
- **CVE-checked.** The dependency is checked against known vulnerability databases at the time of adoption and on every subsequent CI run via the pipeline's automated CVE gate. A dependency with unpatched high-severity CVEs does not land; a dependency that develops an unpatched high-severity CVE after it lands becomes a release blocker until resolved. The CVE check is part of the build, not a periodic chore — if CI is green, the dep tree was clean at build time.
- **Source-reviewed.** Someone on the project has read the source of the dependency, or of the relevant subset, before it lands. "I trust this maintainer" is not a substitute. For large deps, the review can be scoped to the parts we actually use.
- **Recorded.** The reason for adoption, the reviewer, the source SHA or version, and the alternatives considered are captured in the PR that adds it.
- **Justified in place.** Every dependency in `pubspec.yaml` (and equivalent manifests) carries an inline comment explaining what it does, why we took it rather than writing the code, and its license. PR descriptions are not a substitute — the justification must survive in the manifest where future contributors will actually look. If a dependency can't be justified in two or three lines next to its version pin, it probably shouldn't land.

### The "is this worth it" test

Before adding any dependency, answer honestly:

1. What specifically does this do that we cannot reasonably do ourselves?
2. How much code would we write if we did it ourselves? (If the answer is under ~200 lines, strongly prefer writing it.)
3. What is the full transitive dep tree we are accepting?
4. Who maintains it, and what happens to clide if they stop?
5. Is the dependency's scope larger than our need? (Most packages are — we take on all the code, not just the parts we use.)

A dependency that passes this test and the vetting checklist below is welcome. A dependency that passes neither is a no. A dependency that passes one but not the other is a conversation, not a commit.

## Dependency vetting checklist

Before adding any new dependency (direct or transitive) to clide, verify:

**Network behavior**
- Does the package perform network I/O during import, initialization, or first call? If yes, reject or vendor.
- Does the package have a `postinstall`, `setup`, or equivalent script that downloads binaries? If yes, reject or vendor.
- Does any transitive dependency do either of the above? `flutter pub deps` and read the code of anything unfamiliar.

**Binary provenance**
- If the package ships native binaries, are they built from source in the same repo, or fetched from a release artifact? If fetched, treat as a network-at-launch violation.
- If the package expects to download binaries on a different machine (CI, developer setup), that is also disqualifying for runtime deps.

**Maintainership**
- Single-maintainer packages require explicit sign-off and a documented fallback plan. Note the maintainer and last meaningful commit in the PR.
- Packages with no activity in 12+ months require either a fork we control or a decision to own the code ourselves.

**Surface area**
- Prefer packages that do one thing. A dependency that adds 15 transitive deps to solve a 100-line problem should be inlined instead.

**Version pinning, lockfiles, and CVE review**
- See "Dependencies: zero by design" above. All the requirements there apply: exact-pinned, CVE-checked, source-reviewed, justified in place, recorded in the PR.
- `pubspec.lock` (and equivalent lockfiles for other toolchains) is committed to the repository and regenerated on every dependency change. A stale lockfile is a supply-chain hazard: a dependency removed from `pubspec.yaml` that persists in `pubspec.lock` will continue to install in CI and on fresh clones. Lockfile regeneration is part of the dep-change PR, not a follow-up.

**License**
- See License and attribution rules below. A dependency with an incompatible or unclear license is disqualifying regardless of technical merit.

If you can't answer any of these questions, you haven't vetted the dependency yet.

## Removing a dependency

Removal is not the reverse of addition. Adding a dependency involves a single decision and a single commit; removing one involves finding every place the dependency or its transitive siblings have leaked into the codebase and making sure none of them outlive the removal PR.

When removing a dependency:

1. **Grep the entire repository** for references to the package, its exports, and any type names it contributed. `rg '<package>|<PackageType>|<prefix_>'` across the repo. Zero hits outside git history is the goal. A single lingering import will break the build; a single lingering FFI stub or type alias will compile fine and fail at runtime.
2. **Regenerate the lockfile** as part of the same PR. A `pubspec.yaml` with the dep removed but a `pubspec.lock` that still pins it is a partial removal, and CI or a fresh clone will happily continue installing the package.
3. **Update `app/assets/licenses.yaml`** to drop the removed package and any transitive deps it brought in that aren't pulled by anything else. If the license manifest is auto-generated on release, verify the generation script sees the change; if it's maintained by hand, edit it in the same PR.
4. **Remove any vendored artifacts** tied to the dep — binaries, prebuilt assets, generated bindings — and delete their `BUILD.md` records. An orphaned vendored binary is worse than a removed one because it looks legitimate.
5. **Check for architectural assumptions** that the dep was carrying. If the removed package was the thing that justified a specific data flow, build step, or platform strategy, either the replacement picks up those responsibilities or the architecture has actually changed and the relevant design decision (see `decisions/`) needs updating.

A dependency is not removed until all five are true. "I deleted the line from pubspec.yaml" is the start of the removal, not the end.

## Vendored binary rebuild process

clide ships pre-built native libraries (currently `libtree-sitter.so` and per-platform equivalents) vendored into the repository. These binaries are part of the trust boundary: the signed release contains exactly these bytes, and users running clide are running exactly this code.

Every vendored binary has a corresponding `BUILD.md` (or equivalent) next to it in the repo that records:

1. The exact upstream source (git URL and commit SHA, not a version tag).
2. The full build command, including all compile flags.
3. The toolchain version used (compiler, linker, target triple).
4. The expected output size and a SHA-256 hash of the resulting binary.
5. Any patches applied to the source, stored as `.patch` files in the same directory.

Rebuilds are deliberate events, not background maintenance:

- Rebuilds happen in CI, not on a contributor's laptop. A matrix job cross-compiles for all supported platforms and produces the full set of binaries from a single source SHA.
- The rebuild PR updates `BUILD.md`, the binaries, and the hashes in one atomic change. The hash change is the signal in review that binary content changed and must be re-reviewed.
- No binary is committed without a corresponding source SHA and build log. If you can't reproduce the binary from the recorded inputs, the binary is not trustworthy and must be rebuilt.
- Security patches to vendored dependencies are tracked with the same urgency as source-level vulnerabilities. "We're on an old libtree-sitter because rebuilding is annoying" is not acceptable.

Supported platforms and their binary artifacts are documented in the repository root. Dropping a platform requires a policy decision, not a build convenience. Adding a platform requires adding it to the CI matrix and rebuilding all vendored binaries for it before the platform ships.

## Telemetry and phone-home rules

clide does not phone home. The app does not report to any server — ours or anyone else's. This is not a "default off" setting; it is an architectural commitment. clide is a space to think, not a surface for data collection.

This means:

- No analytics SDKs. Not Firebase, not Sentry, not Mixpanel, not a hand-rolled metrics endpoint. Not in debug builds, not in release builds, not behind a feature flag.
- No crash reporters that upload automatically. Crashes produce local logs the user can read and, if they choose, attach to a bug report they submit manually.
- No "check for updates" that runs without the user asking. Update checks are a button.
- No license validation that calls home. clide is MIT; there is nothing to validate.
- No feature flags fetched from a server. Configuration is local.
- No A/B testing, no experiments, no remote config, no "anonymous usage statistics."

If a future contributor proposes telemetry under any framing — opt-in, anonymized, debug-only, "just errors," "just for us," "just to improve the product" — the answer is no. The architectural commitment is the feature. Users installing clide are choosing a tool that does not watch them, and that promise is worth more than any data we could collect.

This rule does not bend. Proposals to add telemetry are out of scope for this project, full stop. If you want telemetry in your editor, clide is not the editor for you, and that's fine — fork it.

## License and attribution rules

clide itself is MIT-licensed. Every dependency, vendored binary, bundled font, and bundled asset must be:

1. Compatible with clide's license.
2. Attributed in the about screen's license manifest.
3. Attributed correctly — the license text and copyright notice must match upstream, not a paraphrase.

### Compatibility matrix

Compatible with clide (permissive): MIT, Apache-2.0, BSD-2/3, ISC, Zlib, Unlicense, CC0.

Compatible with care (copyleft): MPL-2.0 is acceptable for libraries; LGPL is acceptable only for dynamically-linked vendored binaries where we can demonstrate users can replace the library.

Not compatible: GPL (any version) for linked code, AGPL for anything, SSPL, "commercial use prohibited" licenses, custom licenses not reviewed by someone qualified to review them.

When in doubt about a license, the dependency does not land until the question is resolved.

### Attribution requirements

- The license manifest at `app/assets/licenses.yaml` lists every dependency with its license, copyright notice, and upstream URL.
- Transitive dependencies are listed, not just direct ones. If `wasm_run` pulls in `wasmtime` which pulls in `cranelift`, all three appear.
- Apache-2.0 dependencies get their `NOTICE` file content preserved verbatim, not summarized.
- Apache-2.0-with-LLVM-exception (e.g., Cranelift, parts of LLVM) requires the LLVM exception text specifically, not just the Apache-2.0 boilerplate.
- Fonts and icon sets get attributed even if the license doesn't strictly require it. It's the right thing to do.
- `app/assets/licenses.yaml` is regenerated as part of the release build, not maintained by hand. A release that ships a stale manifest is a release defect.

Adding a dependency means updating the license manifest in the same PR. No exceptions.

## Changelog and commit conventions

clide follows [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/) for `CHANGELOG.md` and [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/) for commit messages. Enforcement is handled by the project's git skill; this section exists so human contributors know the standard before their first PR, and so the connection between these conventions and the rest of the policy is explicit.

Security-relevant changes — CVE responses, dependency-driven vulnerability fixes, the removal of a phoning-home transitive dep, anything where the rules in this document were the reason for the change — go under the `Security` heading of the release's changelog entry, regardless of whether the code change itself looks security-shaped. That heading is the trail future-us follows to reconstruct why a dep was bumped or removed. Lumping security fixes under `Fixed` because the diff looks like a normal bug fix loses that signal and is the wrong choice even when it's technically accurate.

## When this policy is wrong

This document is a set of rules, but rules encode judgment calls that may not survive contact with a specific situation. If you think the policy is wrong for a specific case, the process is:

1. Stop. Do not ship the thing.
2. Write down the specific case and why you think the rule fails.
3. Propose a change to this document.
4. Get the change reviewed on its merits.
5. If the change lands, proceed. If not, the rule holds.

"The rule is inconvenient for this task" is not an argument for the rule being wrong. "The rule produces a worse outcome than the alternative, measured against the reasons the rule exists" is.

## Notes for agents

If you are an AI agent working on this repository, the following guidance is binding:

- The default answer to "should I add a dependency" is no. Write the code instead, or use the standard library. If you think a dependency is genuinely warranted, stop and make the case to the human before adding it — do not add it and justify it afterward.
- Do not add dependencies without walking the vetting checklist. Record your answers in the PR description.
- Do not add code that performs network I/O on the default launch path. If you're not sure whether a library does this, read its source before adding it, not after.
- Do not vendor binaries without creating the corresponding `BUILD.md` and recording the source SHA and build command. A committed binary with no reproducibility record is worse than no binary at all.
- Do not add telemetry, analytics, crash reporting, remote config, feature flags, or any other phone-home mechanism under any framing. This is not a "default off" setting; the project does not have telemetry and will not have telemetry. If you think you need it, you are wrong.
- When in doubt, stop and ask the human. Pivoting architectures in a single session to route around a principle is almost always wrong; the principle is there for a reason that may not be visible from inside the task.
