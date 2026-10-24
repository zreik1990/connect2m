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

## Editions

| | **Technician** | **Client** |
|---|---|---|
| For | You and your IT team | The PCs you support |
| Install | `connect2m-Setup.exe` (NSIS, from the server's download page) | `connect2m-Client.msi`, silent: `msiexec /i connect2m-Client.msi /qn` |
| Screen | Connect by ID, file transfer, client list (recent, favourites, shared address book), change own ID | The PC's ID and a hidden password, nothing else |
| Password | Normal one-time/permanent passwords | Fixed by IT (default `System@1`, or the `CONNECT2M_CLIENT_PASSWORD` repository secret); cannot be changed on the PC |
| Sign-in | Local account, Microsoft 365 or Google (via the server) | None |

Both editions:

- Connect only through **your own server** (or directly on the same network), never public servers.
- Never use the **microphone or camera**: sound, voice calls, camera view, recording and the command terminal are switched off.
- Read `connect2m.ini` next to `connect2m.exe` (written by the build): `edition`, `server`, `key`, `api`.

The edition logic is in [`src/connect2m.rs`](src/connect2m.rs).

## Server

[`server/windows`](server/windows) installs the ID/relay server, the sign-in
and shared client list API, the admin page and the download page on a Windows
PC or server. It is published as `connect2m-server-windows.zip`; see its
[README](server/windows/README.md).

## Building

Everything is built by [`.github/workflows/connect2m-windows.yml`](.github/workflows/connect2m-windows.yml):
**Actions** → **Build connect2m for Windows** → **Run workflow**, with your
server's address and key. It publishes a GitHub Release with:

- `connect2m-Setup.exe` / `connect2m-Setup-<version>.exe`: Technician installer
  (NSIS 3, animated, English and Arabic; switches `/S`, `/D=`, `/NODESKTOP`, `/RUN`)
- `connect2m-Client.msi` / `connect2m-Client-<version>.msi`: Client MSI
- `connect2m-<version>-x86_64.exe`: Technician app, portable
- `connect2m-server-windows.zip`: the server

The files are not code-signed, so Windows SmartScreen warns on first run until
they are signed with a code-signing certificate.

Installer artwork is generated from vector drawings for every Windows display
scale by `res/branding/make_installer_art.py` into `res/nsis/art` (see `res/nsis/connect2m-art.nsh`).

## License obligations (AGPL-3.0)

If you give connect2m to anyone, or let people use it over a network, you must
offer them this source code (this repository being public satisfies that), keep
the license and copyright notices, and license your changes under AGPL-3.0 as
well.

The original RustDesk README is kept at
[docs/README-upstream-RustDesk.md](docs/README-upstream-RustDesk.md).
