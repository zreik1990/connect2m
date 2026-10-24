# connect2m server for Windows

connect2m Copyright © 2026 Abdallah Zreik.

This folder sets up everything connect2m needs on one Windows PC or Windows
Server on your network:

| Part | Port(s) | What it does |
|---|---|---|
| ID server (`hbbs.exe`) | 21115, 21116 (TCP+UDP), 21118 | Lets apps find each other by ID |
| Relay (`hbbr.exe`) | 21117, 21119 | Carries a session when two PCs can't connect directly |
| API server (`api\apimain.exe`) | 21114 | Sign-in, the shared client list, admin page, download page |

All three run as background tasks that start with Windows (Task Scheduler →
`connect2m` folder), restart automatically, and accept connections **only
from your local network**.

## 1. Install

1. Unzip `connect2m-server-windows.zip` on the server.
2. Open **PowerShell as administrator** in that folder and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install-Connect2mServer.ps1
   ```
   To use a name instead of the detected IP, add `-ServerAddress connect2m-server`.
3. The script prints, and saves to `C:\connect2m-server\connect2m-server-info.txt`:
   - the **server address** and **server key** (the apps need both)
   - the **admin page** (`http://<server>:21114/_admin/`) with user `admin` and a new password
   - the **download page** (`http://<server>:21114/upload/`)

## 2. Point the apps at this server

The apps are built on GitHub. Open the repository → **Actions** → **Build
connect2m for Windows** → **Run workflow**, and fill in:

- **server**: the server address from step 1
- **key**: the server key from step 1
- tick **Publish a GitHub Release**

When it finishes (about 40 minutes), put the new installers on the download page:

```powershell
C:\connect2m-server\Update-Connect2mDownloads.ps1
```

Once every PC runs the rebuilt apps, run the install script again with
`-RequireKey` so the server only accepts your apps.

## 3. Accounts and the shared client list

- Open the **admin page** and sign in as `admin`.
- **Users**: create an account for each technician (or use Microsoft/Google sign-in below).
- **Address books**: each technician has their own list; share a list with other
  technicians or groups so everyone sees the same clients. In the app, signed-in
  technicians see it under **Address book**, where clients can be renamed,
  tagged and favourited.
- **Logs**: sign-ins, connections and file transfers.

## 4. Sign in with Microsoft 365 or Google (optional)

Microsoft and Google send people back to the server after they sign in, and they
only allow an **https://** address on a **real domain name** (Google rejects IP
addresses). So:

1. Create a DNS name for the server, e.g. `connect2m.yourcompany.com`, pointing
   at its LAN address.
2. Enable HTTPS with your company's certificate (PEM files):
   ```powershell
   C:\connect2m-server\Enable-Connect2mHttps.ps1 -Domain connect2m.yourcompany.com -CertFile C:\certs\c2m.crt -KeyFile C:\certs\c2m.key -LocalNetworkOnly
   ```
   Without `-CertFile/-KeyFile`, Caddy fetches a free certificate automatically,
   which needs the domain reachable from the internet on ports 80 and 443.
3. Register the app with the provider. Redirect URL in both cases:
   `https://connect2m.yourcompany.com/api/oidc/callback`
   - **Microsoft 365 (Entra ID)**: Azure portal → Microsoft Entra ID → App
     registrations → New registration → Web redirect URL as above. Copy the
     **Application (client) ID** and **Directory (tenant) ID**, then create a
     **client secret** under Certificates & secrets.
   - **Google**: Google Cloud console → APIs & Services → Credentials → Create
     OAuth client ID → Web application → Authorised redirect URI as above. Copy
     the client ID and secret.
4. In the connect2m **admin page** → **OAuth**, add:
   - Microsoft: type **OIDC**, Issuer `https://login.microsoftonline.com/<tenant ID>/v2.0`,
     client ID and secret, scopes `openid,email,profile`.
   - Google: type **Google**, client ID and secret.
5. Rebuild the apps with **api** = `https://connect2m.yourcompany.com`.

Sign-in needs the PC to reach Microsoft or Google on the internet at that
moment; remote sessions themselves stay on your network.

## Removing

```powershell
C:\connect2m-server\Uninstall-Connect2mServer.ps1            # keeps data
C:\connect2m-server\Uninstall-Connect2mServer.ps1 -DeleteFiles
```

## Third-party components

- ID server and relay: built from [lejianwen/rustdesk-server](https://github.com/lejianwen/rustdesk-server), GNU AGPL-3.0.
- API server and admin page: [lejianwen/rustdesk-api](https://github.com/lejianwen/rustdesk-api), MIT licence.
- HTTPS: [Caddy](https://github.com/caddyserver/caddy), Apache-2.0 licence.

Their licence files are in the `licenses` folder.
