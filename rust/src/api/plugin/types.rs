use crate::api::plugin::errors::PluginResult;
use crate::api::plugin::traits::Plugin;
use crate::api::plugin::wasm_runtime::SharedWasmEngine;
use std::future::Future;

/// Plugin type enumeration
#[flutter_rust_bridge::frb]
#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum PluginType {
    ContentResolver,
    ChartProvider,
    LyricsProvider,
    SearchSuggestionProvider,
    ContentImporter,
}

impl PluginType {
    pub fn type_string(&self) -> &'static str {
        match self {
            PluginType::ContentResolver => "content-resolver",
            PluginType::ChartProvider => "chart-provider",
            PluginType::LyricsProvider => "lyrics-provider",
            PluginType::SearchSuggestionProvider => "search-suggestion-provider",
            PluginType::ContentImporter => "content-importer",
        }
    }

    pub fn from_string(s: &str) -> Option<Self> {
        let normalized = s.trim().to_lowercase().replace('_', "-");
        match normalized.as_str() {
            "content-resolver"
            | "content_resolver"
            | "metadata-provider"
            | "metadata_provider"
            | "download-provider"
            | "download_provider" => Some(PluginType::ContentResolver),
            "chart-provider" | "chart_provider" => Some(PluginType::ChartProvider),
            "lyrics-provider" | "lyrics_provider" => Some(PluginType::LyricsProvider),
            "search-suggestion-provider" | "search_suggestion_provider" => {
                Some(PluginType::SearchSuggestionProvider)
            }
            "content-importer" | "content_importer" => Some(PluginType::ContentImporter),
            _ => None,
        }
    }

    pub fn description(&self) -> &'static str {
        match self {
            PluginType::ContentResolver => "Content resolver (JioSaavn, etc.)",
            PluginType::ChartProvider => "Chart provider (Billboard, etc.)",
            PluginType::LyricsProvider => "Lyrics provider (synced/plain lyrics)",
            PluginType::SearchSuggestionProvider => "Search suggestions (autocomplete)",
            PluginType::ContentImporter => "Content importer (Spotify, YouTube, etc.)",
        }
    }
}

/// Trait that plugin adapters must implement for automatic registration
pub trait PluginAdapter: Plugin + Sized + Send + Sync + 'static {
    fn plugin_type() -> PluginType;

    fn create(
        name: String,
        wasm_path: String,
        engine: SharedWasmEngine,
    ) -> impl Future<Output = PluginResult<Box<dyn Plugin>>> + Send;
}

/// Status of the plugin installation
#[flutter_rust_bridge::frb]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PluginInstallStatus {
    Installed,
    Updated,
    /// Same or older version was installed (user chose to replace).
    Downgraded,
    AlreadyInstalled,
    PluginLoaded,
    Failed,
}

/// Result of the plugin installation
#[flutter_rust_bridge::frb]
#[derive(Clone, Debug)]
pub struct PluginInstallResult {
    pub status: PluginInstallStatus,
    pub plugin_id: String,
    pub error: Option<String>,
}
