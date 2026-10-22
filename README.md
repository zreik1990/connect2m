<p align="center">
  <img src="res/logo.svg" alt="connect2m" height="72">
</p>

# connect2m

**connect2m** is a remote desktop and remote support app for Windows: help a
customer by seeing and controlling their screen, transfer files, and chat,
with end-to-end encryption.

connect2m Copyright © 2026 Abdallah Zreik.
Based on [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.0, Copyright ©
Purslane Tech Pte. Ltd. and contributors. Licensed under the
[GNU AGPL-3.0](LICENCE). See [NOTICE](NOTICE) for attribution details.

## What's different from RustDesk

| Area | connect2m |
|---|---|
| Name | App name, window titles, installer, install folder (`C:\Program Files\connect2m`), shortcuts and all on-screen text say *connect2m* |
| Logo & icon | New blue/teal logo, app icon, tray icon and installer icon |
| Simple view (new) | Opens on a clean "Get remote help" screen that shows only the ID and one-time password with copy buttons, plus install/permission prompts. One click on **Connect to another computer** switches to the full view, and **Simple view** switches back. The choice is remembered. |
| Colors | Theme accent changed to the connect2m blue, ID highlighted in teal |
| About page | Shows connect2m copyright, the RustDesk attribution and a link to this source code |
| Updates | Does not offer RustDesk's own updates (custom-client mode) |
| Settings folder | `%AppData%\connect2m`, so it does not clash with an installed RustDesk |

## Building the Windows app

The Windows app is built on GitHub's Windows machines with
[`.github/workflows/connect2m-windows.yml`](.github/workflows/connect2m-windows.yml):

1. Open the repository's **Actions** tab and choose **Build connect2m for Windows**.
2. Click **Run workflow**. A build takes roughly 40–60 minutes the first time.
3. Download the **connect2m-windows-x64** artifact. It contains:
   - `connect2m-1.5.0-x86_64.exe`: one file that runs portably and can install itself
   - `connect2m-1.5.0-x86_64.msi`: MSI installer for managed deployments

Pushing a tag such as `v1.5.0` also publishes a GitHub Release with both files.

The files are not code-signed, so Windows SmartScreen will warn on first run
until you sign them with a code-signing certificate.

## Servers

Out of the box connect2m uses the same public ID/relay server as RustDesk.
For business use, run your own free
[RustDesk server](https://github.com/rustdesk/rustdesk-server) and set its
address and key under **Settings → Network → ID/Relay server**, or build them
into the app by changing `RENDEZVOUS_SERVERS` and `RS_PUB_KEY` in
`libs/hbb_common/src/config.rs`.

## License obligations (AGPL-3.0)

If you give connect2m to anyone, or let people use it over a network, you must
offer them this source code (this repository being public satisfies that), keep
the license and copyright notices, and license your changes under AGPL-3.0 as
well.

The original RustDesk README is kept at
[docs/README-upstream-RustDesk.md](docs/README-upstream-RustDesk.md).
