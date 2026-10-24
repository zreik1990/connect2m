// connect2m editions: Technician and Client.
// Copyright © 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0.
//
// One program, two editions, chosen by `connect2m.ini` next to the executable:
//
//   [connect2m]
//   edition=client          ; or "technician" (default)
//   server=192.168.1.10     ; your connect2m server (ID, relay and API)
//   key=xxxxxxxx            ; the server's public key (id_ed25519.pub)
//   api=https://c2m.example.com   ; optional, when login runs behind HTTPS
//
// Values missing from the file fall back to the ones compiled in by the build
// (CONNECT2M_* environment variables), then to the defaults below.
//
// Both editions only ever talk to that server or to computers on the same
// network, and never share sound or camera. The client edition only accepts
// incoming connections, with a fixed password that cannot be changed on the PC.

use std::{collections::HashMap, path::PathBuf};

use base::config::keys;
use hbb_common::{config, log};
use serde_json::{Map, Value};

const INI_FILE: &str = "connect2m.ini";
const DEFAULT_SERVER: &str = "connect2m-server";
const API_PORT: u16 = 21114;
const CLIENT_PASSWORD_SALT: &str = "connect2m-client";
// "00" + base64(sha256("System@1" + CLIENT_PASSWORD_SALT)): the format hbbs
// presets use (see config/permanent_password.rs). The build can replace it via
// CONNECT2M_CLIENT_PASSWORD_STORAGE to rotate the password.
const DEFAULT_CLIENT_PASSWORD_STORAGE: &str = "009b9lp1vf0dHVGxMvJz03Afx4Y3W+MALQfuT1SvL0jMM=";

#[derive(Debug, Clone, PartialEq)]
pub struct Settings {
    pub client: bool,
    pub server: String,
    pub key: String,
    pub api: String,
}

lazy_static::lazy_static! {
    static ref SETTINGS: Settings = read_settings();
}

#[inline]
pub fn is_client_edition() -> bool {
    SETTINGS.client
}

/// Voice calls use the microphone on both ends; connect2m never offers them.
#[inline]
pub fn is_voice_call_disabled() -> bool {
    true
}

fn exe_dir() -> Option<PathBuf> {
    std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
}

fn parse_ini(text: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with(';') || line.starts_with('#') || line.starts_with('[')
        {
            continue;
        }
        if let Some((k, v)) = line.split_once('=') {
            let v = v.split(" ;").next().unwrap_or_default().trim();
            map.insert(k.trim().to_lowercase(), v.trim_matches('"').to_owned());
        }
    }
    map
}

fn non_empty(v: Option<&String>) -> Option<String> {
    v.map(|s| s.trim().to_owned()).filter(|s| !s.is_empty())
}

fn read_settings() -> Settings {
    let ini = exe_dir()
        .map(|d| d.join(INI_FILE))
        .filter(|p| p.is_file())
        .and_then(|p| std::fs::read_to_string(p).ok())
        .map(|t| parse_ini(&t))
        .unwrap_or_default();
    let pick = |name: &str, built: Option<&'static str>, default: &str| -> String {
        non_empty(ini.get(name))
            .or_else(|| built.map(|s| s.trim().to_owned()).filter(|s| !s.is_empty()))
            .unwrap_or_else(|| default.to_owned())
    };
    let edition = pick("edition", option_env!("CONNECT2M_EDITION"), "technician");
    let server = pick("server", option_env!("CONNECT2M_SERVER"), DEFAULT_SERVER);
    let key = pick("key", option_env!("CONNECT2M_KEY"), "");
    let host = server.split(':').next().unwrap_or(DEFAULT_SERVER).to_owned();
    let api = pick(
        "api",
        option_env!("CONNECT2M_API"),
        &format!("http://{host}:{API_PORT}"),
    );
    Settings {
        client: edition.eq_ignore_ascii_case("client"),
        server,
        key,
        api,
    }
}

fn client_password_storage() -> &'static str {
    option_env!("CONNECT2M_CLIENT_PASSWORD_STORAGE")
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(DEFAULT_CLIENT_PASSWORD_STORAGE)
}

fn insert_all(map: &mut Map<String, Value>, items: &[(&str, &str)]) {
    for (k, v) in items {
        map.insert((*k).to_owned(), Value::String((*v).to_owned()));
    }
}

fn overwrite_settings(s: &Settings) -> Map<String, Value> {
    let mut m = Map::new();
    insert_all(
        &mut m,
        &[
            // Only your server, never public ones.
            (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER, s.server.as_str()),
            (keys::OPTION_RELAY_SERVER, s.server.as_str()),
            (keys::OPTION_API_SERVER, s.api.as_str()),
            (keys::OPTION_KEY, s.key.as_str()),
            // Same-network fallbacks that need no server.
            (keys::OPTION_ENABLE_LAN_DISCOVERY, "Y"),
            (keys::OPTION_DIRECT_SERVER, "Y"),
            // No microphone, camera, sound, recording or command terminal.
            (keys::OPTION_ENABLE_AUDIO, "N"),
            (keys::OPTION_ENABLE_CAMERA, "N"),
            (keys::OPTION_ENABLE_RECORD_SESSION, "N"),
            (keys::OPTION_ENABLE_TERMINAL, "N"),
            ("disable-audio", "Y"),
            (keys::OPTION_HIDE_RECORDING_BUTTON, "Y"),
            // Updates come from your own releases, not from the internet.
            (keys::OPTION_ENABLE_CHECK_UPDATE, "N"),
            (keys::OPTION_ALLOW_AUTO_UPDATE, "N"),
            (keys::OPTION_HIDE_SERVER_SETTINGS, "Y"),
            (keys::OPTION_HIDE_PROXY_SETTINGS, "Y"),
            (keys::OPTION_HIDE_WEBSOCKET_SETTINGS, "Y"),
            (keys::OPTION_HIDE_POWERED_BY_ME, "Y"),
        ],
    );
    if s.client {
        insert_all(
            &mut m,
            &[
                (keys::OPTION_VERIFICATION_METHOD, "use-permanent-password"),
                (keys::OPTION_APPROVE_MODE, "password"),
                (keys::OPTION_DISABLE_CHANGE_PERMANENT_PASSWORD, "Y"),
                (keys::OPTION_DISABLE_CHANGE_ID, "Y"),
                (keys::OPTION_REMOVE_PRESET_PASSWORD_WARNING, "Y"),
                (keys::OPTION_HIDE_STOP_SERVICE, "Y"),
                (keys::OPTION_HIDE_SECURITY_SETTINGS, "Y"),
                (keys::OPTION_HIDE_NETWORK_SETTINGS, "Y"),
                (keys::OPTION_HIDE_HELP_CARDS, "Y"),
                (keys::OPTION_ALLOW_HOSTNAME_AS_ID, "Y"),
            ],
        );
    }
    m
}

fn hard_settings(s: &Settings) -> Vec<(&'static str, String)> {
    if !s.client {
        return vec![];
    }
    vec![
        ("conn-type", "incoming".to_owned()),
        ("disable-settings", "Y".to_owned()),
        ("disable-account", "Y".to_owned()),
        ("disable-ab", "Y".to_owned()),
        ("password", client_password_storage().to_owned()),
        ("salt", CLIENT_PASSWORD_SALT.to_owned()),
    ]
}

/// Applies the edition's settings. Called from `load_custom_client`, so every
/// process (GUI, service, tray, connection manager) gets the same rules.
pub fn load_edition() {
    let s = &*SETTINGS;
    let mut map_display = HashMap::new();
    for k in keys::KEYS_DISPLAY_SETTINGS {
        map_display.insert(k.replace('_', "-"), k);
    }
    let mut map_local = HashMap::new();
    for k in keys::KEYS_LOCAL_SETTINGS {
        map_local.insert(k.replace('_', "-"), k);
    }
    let mut map_settings = HashMap::new();
    for k in keys::KEYS_SETTINGS {
        map_settings.insert(k.replace('_', "-"), k);
    }
    let mut map_builtin = HashMap::new();
    for k in keys::KEYS_BUILDIN_SETTINGS {
        map_builtin.insert(k.replace('_', "-"), k);
    }
    crate::common::read_custom_client_advanced_settings(
        Value::Object(overwrite_settings(s)),
        &map_display,
        &map_local,
        &map_settings,
        &map_builtin,
        true,
    );
    let mut hard = config::HARD_SETTINGS.write().unwrap();
    for (k, v) in hard_settings(s) {
        hard.insert(k.to_owned(), v);
    }
    log::info!(
        "connect2m edition: {}, server: {}",
        if s.client { "client" } else { "technician" },
        s.server
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ini_values_are_read_and_trimmed() {
        let m = parse_ini("[connect2m]\nEdition = client\nserver=\"10.0.0.5\" ; LAN\n; note\n");
        assert_eq!(m.get("edition").map(String::as_str), Some("client"));
        assert_eq!(m.get("server").map(String::as_str), Some("10.0.0.5"));
    }

    #[test]
    fn default_client_password_is_system_at_1() {
        let h1 = config::compute_permanent_password_h1("System@1", CLIENT_PASSWORD_SALT);
        let storage = "00".to_owned() + &hbb_common::sodiumoxide::base64::encode(h1, hbb_common::sodiumoxide::base64::Variant::Original);
        assert_eq!(storage, DEFAULT_CLIENT_PASSWORD_STORAGE);
    }
}
