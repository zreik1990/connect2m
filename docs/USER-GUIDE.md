# connect2m — User Guide

connect2m is remote-support software for your own network. A **technician**
sees and controls a **client** PC, sends and receives files, and keeps every
client in one shared list. It never uses the microphone or camera.

There are three parts:

1. **Server** — one Windows PC or server on your network. Connects the apps,
   handles sign-in, and keeps the shared client list.
2. **Technician app** — on your (the helper's) PC.
3. **Client app** — on each PC you support. Shows only its ID and a fixed
   password.

> connect2m works only on your local network. The apps never connect to the
> internet for a session, except that Microsoft/Google sign-in (optional)
> checks the account online at the moment you sign in.

---

## 1. Set up the server (once)

1. On the server PC, download **connect2m-server-windows.zip** from your
   releases page and unzip it (e.g. to `C:\connect2m-server-setup`).
2. Right-click **PowerShell** → **Run as administrator**. Go to that folder:
   ```powershell
   cd C:\connect2m-server-setup\connect2m-server
   powershell -ExecutionPolicy Bypass -File .\Install-Connect2mServer.ps1
   ```
   To use a name instead of the detected IP address:
   ```powershell
   .\Install-Connect2mServer.ps1 -ServerAddress connect2m-server
   ```
3. When it finishes it prints, and saves to
   `C:\connect2m-server\connect2m-server-info.txt`:
   - **Server address** and **Server key** — you need both to build the apps.
   - **Admin page**: `http://<server>:21114/_admin/` with user `admin` and a password.
   - **Download page**: `http://<server>:21114/upload/`.

Keep that file safe. The three server parts now start automatically whenever
Windows starts.

### Put the installers on the download page

After the apps are built for your server (section 2), run:
```powershell
C:\connect2m-server\Update-Connect2mDownloads.ps1
```
Anyone on your network can then open `http://<server>:21114/upload/` and
download the Technician installer or the Client MSI.

---

## 2. Build the apps for your server

The apps are built automatically on GitHub so that every copy points at your
server.

1. Open your connect2m repository on GitHub → **Actions** tab.
2. Choose **Build connect2m for Windows** → **Run workflow**.
3. Fill in:
   - **server**: the server address from section 1.
   - **key**: the server key from section 1.
   - **api**: leave empty (only needed for Microsoft/Google sign-in — section 6).
   - Tick **Publish a GitHub Release**.
4. Wait about 40 minutes. The release page then has:
   - **connect2m-Setup.exe** — Technician installer
   - **connect2m-Client.msi** — Client installer
   - **connect2m-server-windows.zip** — the server (unchanged)

> The client password is **System@1** by default. To use a private password,
> add a repository secret **CONNECT2M_CLIENT_PASSWORD** (Settings → Secrets and
> variables → Actions) before building.

---

## 3. Install the Technician app (on your PC)

1. Open the download page `http://<server>:21114/upload/` and click
   **Download for Windows**, or use `connect2m-Setup.exe` from the release.
2. Run it. If Windows shows "Windows protected your PC", click **More info →
   Run anyway** (this appears until the app is code-signed).
3. Follow the installer: choose a language, accept the terms, keep the default
   folder, and finish. Leave **Run connect2m** ticked.

Silent install (for your own PCs):
```
connect2m-Setup.exe /S
```

### Rename your computer's ID

So clients and your list show a friendly name instead of nine digits:

1. On the connect2m home screen, next to your **ID**, click the small pencil.
2. Type a name, e.g. `ABDALLAH-PC` (letters, numbers and dashes; 6–16 characters).
3. Click **OK**.

---

## 4. Install the Client app (on PCs you support)

**On the PC itself:** download **connect2m-Client.msi** from the download page
and run it.

**Remotely / to many PCs at once** (from an elevated command prompt, Intune,
Group Policy, PDQ, etc.):
```
msiexec /i connect2m-Client.msi /qn
```
Options you can add:
- Different password for this batch: `C2M_PASSWORD=YourPassword`
- Different server/key: `C2M_SERVER=10.0.0.5 C2M_KEY=abc...`

Example:
```
msiexec /i connect2m-Client.msi C2M_PASSWORD=Spring#2026 /qn
```

The client screen shows only the **ID** (the PC's name) and a hidden password.
The password is set by you and **cannot be changed on the client PC**.

---

## 5. Connect to a client

1. Open the Technician app.
2. Type the client's **ID** (its computer name) in **Control Remote Desktop**
   and click **Connect**.
3. Enter the client password (e.g. `System@1`). Tick **Remember** to save it.
4. You now see the client's screen and can control it.

**On the client**, a small window shows your name and a **Disconnect** button,
so the person always knows you are connected and can end it.

### Install an app on the client

Because you control the client's screen, you can download and install software
on it exactly as if you were sitting there: open its browser, download the
installer, and run it. If Windows asks for an administrator password (UAC), the
person at the client may need to approve it, unless the client runs the service
with the needed rights.

### Send and receive files

- In the connection toolbar, open **Transfer file**, or
- From the home screen, next to the ID, choose **Transfer file** instead of
  Connect.

A two-pane window opens: your PC on the left, the client on the right. Drag
files either way, or use the upload/download buttons.

---

## 6. Sign in with Microsoft 365 or Google (optional)

Sign-in lets technicians log in with their work account and share one client
list. It needs the server to have an **https:// web address on a real domain
name** (Microsoft and Google refuse plain IP addresses).

1. Create a DNS name for the server, e.g. `connect2m.yourcompany.com`.
2. On the server, enable HTTPS:
   ```powershell
   C:\connect2m-server\Enable-Connect2mHttps.ps1 -Domain connect2m.yourcompany.com `
     -CertFile C:\certs\c2m.crt -KeyFile C:\certs\c2m.key -LocalNetworkOnly
   ```
3. Register the app with Microsoft or Google. Redirect URL in both:
   `https://connect2m.yourcompany.com/api/oidc/callback`
4. In the connect2m **admin page → OAuth**, add the client ID and secret.
5. Rebuild the apps (section 2) with **api** = `https://connect2m.yourcompany.com`.

Full steps are in the server README inside the server zip.

### The shared client list

- In the admin page, create a user for each technician, or use the sign-in above.
- Under **Address books**, share one list with your technicians.
- In the Technician app, after signing in (top-right), open **Address book** to
  see the shared list. Right-click a client to **rename**, **tag** or mark it a
  **favourite**.

---

## 7. Licensing and selling

connect2m is based on RustDesk and licensed under the **GNU AGPL-3.0**. You may
sell it, but the source code must stay available to anyone who gets the app, and
buyers may modify and share it. See the project README for details.

---

## 8. Troubleshooting

| Problem | What to check |
|---|---|
| Client shows "Not ready, please wait" | The server isn't reachable. Check the client and server are on the same network; on the server, confirm the `connect2m-id` task is running (Task Scheduler → connect2m). |
| "Key mismatch" when connecting | The app's key doesn't match the server. Rebuild the apps with the current server key, or reinstall the server without `-RequireKey`. |
| Can't sign in with Microsoft/Google | Sign-in needs HTTPS on a real domain and internet access at that moment. See section 6. |
| Windows SmartScreen warning | Expected until the app is code-signed. Click **More info → Run anyway**. |
| Wrong password on client | The password is set at build time (default `System@1`) or at install with `C2M_PASSWORD=`. Reinstall the client to change it. |
| Server logs | `C:\connect2m-server\logs\` (hbbs.log, hbbr.log, api.log). |

---

*connect2m — Copyright © 2026 Abdallah Zreik. Based on RustDesk (AGPL-3.0).*
