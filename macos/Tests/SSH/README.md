# SSH session manager checks

The macOS app exposes **File → SSH Connections…**. Add a host or existing SSH alias, select an authentication method, and save. Double-click or Enter opens a tab; the context menu also opens a window. Passwords/key passphrases are opt-in Keychain entries. Changing connection/key settings clears saved credentials unless they are entered again.

The launcher retains SSH output and offers `R` + Enter to reconnect, `M` + Enter to retry with manual authentication, or Enter to finish. Additional authentication and host confirmation use an app dialog. Saved passwords are only submitted to direct password authentication; jump hosts and OTP require manual input. SSH certificates use the selected private key and public certificate; the server may also accept the same key without the certificate.

## Core tests without GhosttyKit

```sh
sh macos/Tests/SSH/run-core-tests.sh
```

Uses a temporary Swift package to run the same Swift Testing test sources included in the app test target. Tests cover profile validation, command boundaries, authentication prompt matching, credential binding/single-use isolation, private atomic storage/conflicts, and foreground process-group inheritance.

## Local OpenSSH integration

```sh
python3 macos/Tests/SSH/verify-openssh.py
python3 macos/Tests/SSH/verify-openssh.py --signed-helper
```

The script starts an unprivileged sshd on a random localhost port with disposable keys and a CA. The first check verifies certificate authentication and forced askpass with an encrypted key under a PTY. The optional signed-helper check compiles the actual product helper sources into a disposable ad-hoc signed app and uses one temporary Keychain item to verify caller validation, Keychain retrieval, certificate authentication, and interactive input in a controlling PTY. It deletes the item on normal success/failure. If forcibly killed, remove the disposable `Ghostty SSH: Disposable test` item in Keychain Access. No existing SSH config, known_hosts, keys, or credentials are changed.

`--diagnose` prints only disposable process paths and signature check results on test failure. The test fixture ends in `.swift.txt` so Xcode does not compile it into the regular test target.

## Full application validation

Follow `macos/AGENTS.md`: build GhosttyKit first when needed, then run `macos/build.nu --action build` and `macos/build.nu --action test`. Test UI operations, Keychain denial/cancellation, changed host keys, OTP, multiple simultaneous connections, and closing a tab with an active authentication dialog. The isolated checks do not replace full application/UI testing.


## Validation in this workspace

Native arm64 GhosttyKit and Debug app builds succeeded after installing Nushell 0.116.1, Zig 0.17.1 and Metal Toolchain 17F109. All 14 SSH tests passed in Xcode as well as the isolated core suite. The complete app unit-test run reported 303 passed, 1 failed and 1 skipped: the existing KeyboardLayoutTests.characterAppliesModifiers expects shifted KeyA to differ, but the current Korean layout produces ㅁ in both cases. The built debug app was launched; interactive UI inspection remains unconfirmed because the automation tool timed out attaching to its accessibility tree.
