use crate::api::plugin::errors::{PluginError, PluginResult};
use serde::de::{self, Deserializer};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[flutter_rust_bridge::frb]
pub const CURRENT_MANIFEST_VERSION: u32 = 1;

/// Plugin publisher information
#[flutter_rust_bridge::frb]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PluginPublisher {
    #[serde(default)]
    pub name: String,
    pub url: Option<String>,
    pub contact: Option<String>,
    pub key_id: Option<String>,
}

impl Default for PluginPublisher {
    fn default() -> Self {
        PluginPublisher {
            name: "SpotiFLAC / Audiophile Provider".to_string(),
            url: None,
            contact: None,
            key_id: None,
        }
    }
}

fn default_publisher() -> PluginPublisher {
    PluginPublisher::default()
}

/// Describes a required key/credential for a plugin.
///
/// JSON format:
/// ```json
/// {
///   "api_key": {
///     "description": "API key for authenticating",
///     "default": null,
///     "is_secret": true
///   }
/// }
/// ```
#[flutter_rust_bridge::frb]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct KeyRequirement {
    /// Human-readable description of what this key is used for.
    pub description: String,
    /// Default value for this key. `None` means user must provide it.
    #[serde(default, rename = "default")]
    pub default_value: Option<String>,
    /// Whether this key should be treated as a secret (masked in UI).
    #[serde(default)]
    pub is_secret: bool,
}

fn default_manifest_version() -> u32 {
    1
}

fn default_version() -> String {
    "1.0.0".to_string()
}

fn default_plugin_type() -> String {
    "content_resolver".to_string()
}

#[flutter_rust_bridge::frb]
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Manifest {
    #[serde(
        default = "default_manifest_version",
        deserialize_with = "deserialize_manifest_version"
    )]
    pub manifest_version: u32,

    #[serde(default, deserialize_with = "deserialize_id_or_name")]
    pub id: String,

    #[serde(default)]
    pub name: String,

    #[serde(default = "default_version")]
    pub version: String,

    #[serde(
        default = "default_plugin_type",
        deserialize_with = "deserialize_plugin_type"
    )]
    pub r#type: String,

    #[serde(default)]
    pub description: String,

    #[serde(default = "default_publisher", deserialize_with = "deserialize_publisher_flexible")]
    pub publisher: PluginPublisher,

    #[serde(default)]
    pub license: String,

    #[serde(default)]
    pub homepage: String,

    pub icon: Option<String>,

    #[serde(default)]
    pub host_site: Vec<String>,

    #[serde(default, deserialize_with = "deserialize_capabilities_flexible")]
    pub capabilities: Vec<String>,

    pub created_at: Option<String>,
    pub remote_url: Option<String>,

    #[serde(default)]
    pub keys_required: HashMap<String, KeyRequirement>,

    pub thumbnail_url: Option<String>,

    #[serde(default)]
    pub resolver: bool,

    pub last_updated: Option<String>,

    #[serde(default)]
    pub country_allowlist: Vec<String>,
}

fn deserialize_id_or_name<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(s) if !s.trim().is_empty() => Ok(s),
        serde_json::Value::Null => Ok(String::new()),
        _ => Ok(String::new()),
    }
}

fn deserialize_plugin_type<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(s) => Ok(s),
        serde_json::Value::Array(arr) => {
            // SpotiFLAC extension manifests use array: ["metadata_provider", "download_provider"]
            if arr.iter().any(|v| v.as_str() == Some("download_provider") || v.as_str() == Some("metadata_provider")) {
                Ok("content_resolver".to_string())
            } else if let Some(first) = arr.first().and_then(|v| v.as_str()) {
                Ok(first.to_string())
            } else {
                Ok("content_resolver".to_string())
            }
        }
        _ => Ok("content_resolver".to_string()),
    }
}

/// Deserialize `capabilities` which in SpotiFLAC manifests can be:
///   - an array of strings  ["search", "download"]
///   - an object            {"downloadFallbackTier": "lossless", ...}  → extract string values
///   - a plain string       "download"
///   - absent / null        → empty vec
fn deserialize_capabilities_flexible<'de, D>(deserializer: D) -> Result<Vec<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::Array(arr) => Ok(arr
            .into_iter()
            .filter_map(|v| match v {
                serde_json::Value::String(s) if !s.trim().is_empty() => Some(s),
                _ => None,
            })
            .collect()),
        serde_json::Value::Object(map) => {
            // SpotiFLAC uses an object like {"downloadFallbackTier": "lossless"}
            // Extract the string values as capability tags
            let caps: Vec<String> = map
                .into_iter()
                .filter_map(|(_, v)| match v {
                    serde_json::Value::String(s) if !s.trim().is_empty() => Some(s),
                    _ => None,
                })
                .collect();
            Ok(caps)
        }
        serde_json::Value::String(s) if !s.trim().is_empty() => Ok(vec![s]),
        _ => Ok(Vec::new()),
    }
}

fn deserialize_publisher_flexible<'de, D>(deserializer: D) -> Result<PluginPublisher, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::Object(_) => {
            PluginPublisher::deserialize(value).map_err(de::Error::custom)
        }
        serde_json::Value::String(pub_name) => Ok(PluginPublisher {
            name: pub_name,
            url: None,
            contact: None,
            key_id: None,
        }),
        _ => Ok(PluginPublisher {
            name: "SpotiFLAC / Audiophile Provider".to_string(),
            url: None,
            contact: None,
            key_id: None,
        }),
    }
}

fn parse_plugin_version(version: &str) -> Option<u64> {
    let trimmed = version.trim().trim_start_matches('v');
    if trimmed.is_empty() {
        return None;
    }
    if let Ok(num) = trimmed.parse::<u64>() {
        return Some(num);
    }
    if let Some((major, _)) = trimmed.split_once('.') {
        if let Ok(num) = major.parse::<u64>() {
            return Some(num);
        }
    }
    Some(1)
}

fn deserialize_manifest_version<'de, D>(deserializer: D) -> Result<u32, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::Number(number) => {
            let as_u64 = number
                .as_u64()
                .unwrap_or(1);
            Ok(u32::try_from(as_u64).unwrap_or(1))
        }
        serde_json::Value::String(text) => {
            let trimmed = text.trim();
            if let Ok(v) = trimmed.parse::<u32>() {
                return Ok(v);
            }
            if let Some((whole, _)) = trimmed.split_once('.') {
                if let Ok(whole_num) = whole.parse::<u32>() {
                    return Ok(whole_num);
                }
            }
            Ok(1)
        }
        _ => Ok(1),
    }
}

impl Manifest {
    /// Load and validate a manifest from a JSON file
    #[flutter_rust_bridge::frb(ignore)]
    pub async fn from_file(file_path: &str) -> PluginResult<Self> {
        let content = tokio::fs::read_to_string(file_path).await.map_err(|e| {
            PluginError::ManifestParseError(format!(
                "Failed to read manifest file '{}': {}",
                file_path, e
            ))
        })?;

        // Strip UTF-8 Byte Order Mark (BOM) if present (\u{feff})
        let clean_content = content.trim_start_matches('\u{feff}');

        // Parse JSON into raw value first to ensure id/name fallback
        let mut raw_val: serde_json::Value = serde_json::from_str(clean_content).map_err(|e| {
            PluginError::ManifestParseError(format!(
                "Failed to parse manifest JSON from '{}': {}",
                file_path, e
            ))
        })?;

        if let serde_json::Value::Object(ref mut map) = raw_val {
            // Fallback id to name if id is missing or empty
            let has_id = map.get("id").and_then(|v| v.as_str()).map(|s| !s.trim().is_empty()).unwrap_or(false);
            if !has_id {
                let fallback_id = map.get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown_plugin")
                    .to_string();
                map.insert("id".to_string(), serde_json::Value::String(fallback_id));
            }

            // Fallback name to id if name is missing or empty
            let has_name = map.get("name").and_then(|v| v.as_str()).map(|s| !s.trim().is_empty()).unwrap_or(false);
            if !has_name {
                let fallback_name = map.get("id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown Plugin")
                    .to_string();
                map.insert("name".to_string(), serde_json::Value::String(fallback_name));
            }
        }

        let manifest: Manifest = serde_json::from_value(raw_val).map_err(|e| {
            PluginError::ManifestParseError(format!(
                "Failed to deserialize manifest from '{}': {}",
                file_path, e
            ))
        })?;

        manifest.validate()?;

        Ok(manifest)
    }

    /// Create a new manifest from parameters
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(
        id: String,
        name: String,
        version: String,
        plugin_type: String,
        description: String,
        publisher: PluginPublisher,
        license: String,
        homepage: String,
        icon: Option<String>,
        host_site: Vec<String>,
        capabilities: Vec<String>,
        created_at: Option<String>,
        remote_url: Option<String>,
    ) -> PluginResult<Self> {
        let manifest = Manifest {
            manifest_version: 1,
            id,
            name,
            version,
            r#type: plugin_type,
            description,
            publisher,
            license,
            homepage,
            icon,
            host_site,
            capabilities,
            created_at,
            remote_url,
            keys_required: HashMap::new(),
            thumbnail_url: None,
            resolver: false,
            last_updated: None,
            country_allowlist: Vec::new(),
        };

        // Validate the manifest
        manifest.validate()?;

        Ok(manifest)
    }

    /// Validate manifest structure
    #[flutter_rust_bridge::frb(ignore)]
    fn validate(&self) -> PluginResult<()> {
        // Removed strict manifest_version check here to allow parsing legacy/future manifests.
        // It should be validated at install time instead.

        // Validate required string fields are not empty
        // Note: 'description' is optional for SpotiFLAC-format plugins.
        let required_strings = vec![
            ("id", &self.id),
            ("name", &self.name),
            ("version", &self.version),
            ("type", &self.r#type),
        ];

        for (field_name, value) in required_strings {
            if value.trim().is_empty() {
                return Err(PluginError::ManifestParseError(format!(
                    "Required field '{}' cannot be empty",
                    field_name
                )));
            }
        }

        if parse_plugin_version(&self.version).is_none() {
            return Err(PluginError::ManifestParseError(
                "Invalid plugin version: expected a version string (e.g. '1', '1.2.0', 'v2.3.1')"
                    .to_string(),
            ));
        }

        // Validate publisher name is not empty
        if self.publisher.name.trim().is_empty() {
            return Err(PluginError::ManifestParseError(
                "Publisher name cannot be empty".to_string(),
            ));
        }

        // Validate icon if present
        if let Some(ref icon) = self.icon {
            if icon.trim().is_empty() {
                return Err(PluginError::ManifestParseError(
                    "Icon field cannot be empty if provided".to_string(),
                ));
            }
        }

        // Validate all host_site entries are valid URLs (basic check)
        for host in &self.host_site {
            if host.trim().is_empty() {
                return Err(PluginError::ManifestParseError(
                    "host_site entries cannot be empty".to_string(),
                ));
            }
            if !host.starts_with("http://") && !host.starts_with("https://") {
                return Err(PluginError::ManifestParseError(format!(
                    "host_site '{}' must be a valid HTTP/HTTPS URL",
                    host
                )));
            }
        }

        // Validate capabilities are valid strings
        for capability in &self.capabilities {
            if capability.trim().is_empty() {
                return Err(PluginError::ManifestParseError(
                    "capabilities entries cannot be empty".to_string(),
                ));
            }
        }

        // Validate homepage is a valid URL when provided
        if !self.homepage.trim().is_empty()
            && !self.homepage.starts_with("http://")
            && !self.homepage.starts_with("https://")
        {
            return Err(PluginError::ManifestParseError(format!(
                "homepage '{}' must be a valid HTTP/HTTPS URL",
                self.homepage
            )));
        }

        Ok(())
    }

    /// Check if the manifest is still valid (re-run validation)
    #[flutter_rust_bridge::frb(ignore)]
    pub fn check(&self) -> PluginResult<()> {
        self.validate()
    }

    /// Get the plugin ID
    #[flutter_rust_bridge::frb(ignore)]
    pub fn id(&self) -> &str {
        &self.id
    }

    /// Get the plugin name
    #[flutter_rust_bridge::frb(ignore)]
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Get the plugin type
    #[flutter_rust_bridge::frb(ignore)]
    pub fn plugin_type(&self) -> &str {
        &self.r#type
    }

    /// Check if the plugin supports a specific capability
    #[flutter_rust_bridge::frb(ignore)]
    pub fn has_capability(&self, capability: &str) -> bool {
        self.capabilities.contains(&capability.to_string())
    }

    /// Get all capabilities
    #[flutter_rust_bridge::frb(ignore)]
    pub fn capabilities(&self) -> &[String] {
        &self.capabilities
    }

    /// Get all host sites
    #[flutter_rust_bridge::frb(ignore)]
    pub fn host_sites(&self) -> &[String] {
        &self.host_site
    }

    /// Get the publisher information
    #[flutter_rust_bridge::frb(ignore)]
    pub fn publisher(&self) -> &PluginPublisher {
        &self.publisher
    }

    /// Get the icon path (if available)
    #[flutter_rust_bridge::frb(ignore)]
    pub fn icon(&self) -> Option<&str> {
        self.icon.as_deref()
    }

    /// Get the creation timestamp (if available)
    #[flutter_rust_bridge::frb(ignore)]
    pub fn created_at(&self) -> Option<&str> {
        self.created_at.as_deref()
    }
}

#[cfg(test)]
mod tests {
    use super::Manifest;

    #[test]
    fn parses_legacy_manifest_and_passes_validation() {
        // Test legacy manifest format (string manifest_version, missing optional fields)
        let json = r#"{
            "manifest_version": "1.0",
            "id": "com.example.legacy-plugin",
            "name": "Legacy Plugin",
            "version": "1",
            "type": "content-resolver",
            "publisher": {
                "name": "Example Publisher",
                "url": "https://example.com",
                "contact": "contact@example.com"
            },
            "description": "Example legacy plugin without optional metadata fields.",
            "created_at": "2025-12-10T00:00:00Z"
        }"#;

        let manifest: Manifest = serde_json::from_str(json).expect("manifest should parse");
        assert_eq!(manifest.manifest_version, 1);
        assert!(manifest.license.is_empty());
        assert!(manifest.homepage.is_empty());
        assert!(manifest.host_site.is_empty());
        assert!(manifest.capabilities.is_empty());
        manifest.validate().expect("manifest should validate");
    }

    #[test]
    fn rejects_manifest_with_empty_id() {
        // A manifest with an empty id should always fail validation.
        let json = r#"{
            "manifest_version": "1",
            "id": "",
            "name": "",
            "version": "1",
            "type": "content-resolver",
            "publisher": { "name": "Example Inc" },
            "description": "Example plugin"
        }"#;

        let manifest: Manifest = serde_json::from_str(json).expect("manifest should parse");
        assert!(manifest.validate().is_err());
    }

    #[test]
    fn accepts_semver_plugin_version() {
        // SpotiFLAC plugins use semver like "1.2.0" — this must now pass validation.
        let json = r#"{
            "manifest_version": "1",
            "id": "com.example.plugin",
            "name": "Example",
            "version": "1.0.0",
            "type": "content-resolver",
            "publisher": { "name": "Example Inc" },
            "description": "Example plugin"
        }"#;

        let manifest: Manifest = serde_json::from_str(json).expect("manifest should parse");
        // semver is now accepted
        assert!(manifest.validate().is_ok());
    }

    #[test]
    fn accepts_spotiflac_manifest_with_object_capabilities() {
        // Deezer .sflx manifest uses: "capabilities": {"downloadFallbackTier": "lossless"}
        // Note: id-from-name fallback only runs in from_file(); in unit tests we provide id directly.
        let json = r#"{
            "id": "deezer",
            "name": "deezer",
            "version": "1.2.0",
            "description": "Deezer plugin",
            "type": ["metadata_provider", "download_provider"],
            "capabilities": {
                "downloadFallbackTier": "lossless"
            }
        }"#;

        let manifest: Manifest = serde_json::from_str(json).expect("manifest should parse");
        assert_eq!(manifest.id, "deezer");
        assert_eq!(manifest.name, "deezer");
        assert_eq!(manifest.r#type, "content_resolver");
        // Object capabilities → extracted string values ("lossless")
        assert!(!manifest.capabilities.is_empty());
        assert!(manifest.validate().is_ok());
    }
}
