# Windows development and iOS preparation

## Run the existing app locally

From `rozz_app`, run `powershell -File tool/run_preview.ps1`, or choose
**ROZZ: Windows phone preview** in VS Code with the Dart/Flutter extension.
Install Visual Studio Build Tools 2022 with C++ desktop tools, CMake and a
Windows SDK and the ATL component first (secure-storage plugin dependency). `flutter doctor -v` checks these prerequisites.

The debug-only `ROZZ_DESKTOP_PREVIEW=true` flag opens the existing screens in
a phone-sized viewport. It uses an isolated, in-memory SQLite ledger and
in-memory settings; restarting the process clears both. Hot reload preserves
current state. No mobile database, bank credentials, or real messages are used.
Current-month synthetic balance advice goes through the real parser/ingest
pipeline. **Simulate SMS** exercises that same pipeline and refreshes the BLoCs.
Contacts are disabled in the preview. AI needs a key entered for that session;
no build-time key is imported. Network features still need their own setup.

This is a Flutter desktop preview, not an iOS emulator. Test actual iOS
Shortcuts, permissions, encryption and locked-device behavior on the iPhone.

## Build a package using a cloud Mac

`.github/workflows/ios-sideload.yml` is a manually triggered workflow. Once
available on GitHub, select Actions > iOS sideload package > Run workflow.
It uses Flutter 3.41.2, runs analysis/tests and builds the existing app on a
standard macOS runner. Download `rozz-ios-unsigned` and extract the IPA.
The package is unsigned; AltStore/another compatible sideloader must re-sign
it locally before installation. No Apple Account credentials or API keys go
into GitHub Actions. Artifacts expire after three days.

The workflow is prepared locally, not yet run or verified on macOS. Standard
GitHub-hosted runner compute is free for public repositories; artifact storage
has separate allowances. Keep retention short and remove obsolete artifacts.

## iOS readiness: still pending

- Native App Intent receiving message text from Shortcuts.
- Durable, encrypted incoming-message handoff and shared ingest drain.
- Locked-device ingestion, process termination, restart and retry tests.
- SMS automation setup on the user's iOS 27 device.
- Sideload signing/renewal and update persistence tests on that device.
- Keychain configuration and app-lock replacement for Android Keyguard.
- Background refresh and EOD semantics for incomplete SMS coverage.
- Secure transfer of the existing Android ledger.

The initial iOS configuration sets the deployment target to 14.0 for the
installed WorkManager plugin and declares optional contacts access. iOS no
longer auto-loads mock SMS. This is build preparation, not a claim that every
feature already works on iPhone. The existing Android capture remains intact.

