# Building APKs

## Default: GitHub Actions builds it

`.github/workflows/android.yml` builds a signed **debug** APK and publishes it as a GitHub
**Release** with a direct download link, when:

| Trigger | How |
|---|---|
| You ask for one | push a commit whose message contains `[apk]` — any branch. Claude does this when you say "build me an APK": `git commit --allow-empty -m "[apk] build for phone testing"` |
| A PR merges into `main` | automatic — `main` always has a fresh build (tag `apk-pr-<N>`) |
| By hand | Actions → *Android APK* → *Run workflow* |

The link looks like `https://github.com/<you>/<repo>/releases/download/apk-<N>/<repo>.apk`. Open it
on your phone, download, install (allow "install unknown apps" for your browser once). To get each
link by email: Watch → Custom → Releases.

**Why not on every push:** free Actions minutes are finite. Pushes without `[apk]` start a run that
skips in seconds. Old builds are pruned (last 5 PR builds, last 10 others). No run artifacts are
kept — the Release is the one copy, so the Actions storage quota doesn't fill up.

The tests workflow (`ci.yml`) runs on pull requests and on `main`, not on every branch push —
Claude runs `./run_tests.sh` in the session before each commit anyway.

Your fork needs nothing configured: the workflow uses the built-in `GITHUB_TOKEN`. If Actions are
disabled on your fork, enable them (Actions tab → *I understand…*).

## Fallback: build inside the Claude Code session

```bash
tools/android_build.sh            # → build/<repo>.apk, signature verified
tools/android_build.sh --publish  # …and push it to the `media` branch, print a phone link
```

Works on the Default network policy, without Google's SDK (which is blocked there): `apksigner`,
`zipalign` and `adb` come from Ubuntu's apt archive, export templates (~1.2 GB, once per session)
from GitHub, and the preset uses `use_gradle_build=false` so no Gradle or NDK is involved. Takes
about 3 minutes the first time. Prefer CI — the media branch is for when CI is not an option.

## On a Mac

1. Godot 4.7 in `/Applications` (see README).
2. Editor → *Manage Export Templates* → *Download and Install*.
3. `brew install --cask temurin@17 android-commandlinetools`, then
   `sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35"`.
4. Editor → *Editor Settings* → *Export → Android*: SDK path `/opt/homebrew/share/android-commandlinetools`,
   JDK path `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`; debug keystore
   `ci/debug.keystore`, user `androiddebugkey`, password `android`.
5. *Project → Export → Android → Export Project*, or `tools/android_build.sh`.

## Signing

Builds are signed with the **public Android debug key** in `ci/debug.keystore`. That is fine for
installing on your own devices and sharing test builds. It is **not** for the Play Store: for a
release, create your own keystore, keep it out of the repo, and add it as GitHub secrets.

## Your package id

Change `com.example.godotclaudeletsgo` before you share builds:
`tools/rename_game.sh "My Game" com.yourname.mygame`.
