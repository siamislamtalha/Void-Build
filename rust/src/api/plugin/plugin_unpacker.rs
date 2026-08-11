use crate::api::plugin::manifest::{Manifest, CURRENT_MANIFEST_VERSION};
use crate::api::plugin::registrar::get_plugin_type_from_string;
use crate::api::plugin::types::{PluginInstallResult, PluginInstallStatus};
use anyhow::{Context, Result};
use std::cmp::Ordering;
use std::fs::File;
use std::io::{BufReader, Read};
use tar::Archive;
use zstd::stream::read::Decoder;

/// Parse a version string into a comparable u64 for version comparison.
/// Accepts integer strings ("1", "42") and semver ("1.2.0", "v2.3.1").
/// Returns the major version number so older/newer comparisons still work.
fn parse_version_int(version: &str) -> Option<u64> {
    let trimmed = version.trim().trim_start_matches('v');
    if trimmed.is_empty() {
        return None;
    }
    // Try plain integer first
    if let Ok(num) = trimmed.parse::<u64>() {
        return Some(num);
    }
    // Accept semver: extract major.minor.patch and form a comparable u64
    let parts: Vec<&str> = trimmed.splitn(3, '.').collect();
    let major = parts.first().and_then(|s| s.parse::<u64>().ok()).unwrap_or(0);
    let minor = parts.get(1).and_then(|s| s.parse::<u64>().ok()).unwrap_or(0);
    let patch = parts.get(2)
        .and_then(|s| s.split('-').next()) // strip pre-release e.g. "0-beta"
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(0);
    Some(major * 1_000_000 + minor * 1_000 + patch)
}

pub async fn unpack_and_read_manifest(
    archive_path: &str,
    temp_dir: &str,
) -> Result<(Manifest, String)> {
    let now_nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .context("System clock before UNIX_EPOCH")?
        .as_nanos();

    let temp_plugin_dir = format!(
        "{}/plugin_temp_{}",
        temp_dir,
        now_nanos
    );

    unpack_plugin(archive_path, &temp_plugin_dir, None).await?;

    let manifest_path = format!("{}/manifest.json", temp_plugin_dir);
    let manifest = Manifest::from_file(&manifest_path)
        .await
        .with_context(|| format!("Failed to load manifest from '{}'", manifest_path))?;

    Ok((manifest, temp_plugin_dir))
}

pub async fn install_plugin(
    temp_plugin_dir: &str,
    manifest: &Manifest,
    plugins_dir: &str,
) -> Result<(String, PluginInstallStatus)> {
    let plugin_install_dir = format!("{}/{}", plugins_dir, manifest.id);
    let path = std::path::Path::new(&plugin_install_dir);

    let mut status = PluginInstallStatus::Installed;

    if path.exists() {
        // Check existing plugin version for comparison
        let existing_manifest_path = path.join("manifest.json");
        if existing_manifest_path.exists() {
            let existing_manifest_path_string =
                existing_manifest_path.to_string_lossy().to_string();
            if let Ok(existing_manifest) = Manifest::from_file(&existing_manifest_path_string).await
            {
                if let (Some(new_ver), Some(old_ver)) = (
                    parse_version_int(&manifest.version),
                    parse_version_int(&existing_manifest.version),
                ) {
                    match new_ver.cmp(&old_ver) {
                        Ordering::Greater => {
                            status = PluginInstallStatus::Updated;
                        }
                        Ordering::Equal => {
                            status = PluginInstallStatus::AlreadyInstalled;
                        }
                        Ordering::Less => {
                            status = PluginInstallStatus::Downgraded;
                        }
                    }
                }
            }
        }

        // Remove existing
        tokio::fs::remove_dir_all(&plugin_install_dir)
            .await
            .with_context(|| {
                format!(
                    "Failed to remove existing plugin at '{}'",
                    plugin_install_dir
                )
            })?;
    }

    tokio::fs::create_dir_all(&plugin_install_dir)
        .await
        .with_context(|| format!("Failed to create directory '{}'", plugin_install_dir))?;

    // Recursively copy every file from temp_plugin_dir to plugin_install_dir.
    // SpotiFLAC .sflx archives contain index.js, assets, config files, etc.
    // in addition to the standard manifest.json / plugin.wasm / plugin.wit.
    copy_dir_all(temp_plugin_dir, &plugin_install_dir).with_context(|| {
        format!(
            "Failed to copy plugin files from '{}' to '{}'",
            temp_plugin_dir, plugin_install_dir
        )
    })?;

    Ok((manifest.id.clone(), status))
}

/// Recursively copy all contents of `src` into `dst`.
fn copy_dir_all(src: &str, dst: &str) -> Result<()> {
    let src_path = std::path::Path::new(src);
    let dst_path = std::path::Path::new(dst);
    std::fs::create_dir_all(dst_path)
        .with_context(|| format!("Failed to create directory '{}'", dst))?;
    for entry in std::fs::read_dir(src_path)
        .with_context(|| format!("Failed to read directory '{}'", src))?
    {
        let entry = entry.with_context(|| format!("Failed to read entry in '{}'", src))?;
        let entry_type = entry.file_type()
            .with_context(|| format!("Failed to get file type for '{:?}'", entry.path()))?;
        let target = dst_path.join(entry.file_name());
        if entry_type.is_dir() {
            copy_dir_all(
                &entry.path().to_string_lossy().to_string(),
                &target.to_string_lossy().to_string(),
            )?;
        } else {
            std::fs::copy(entry.path(), &target).with_context(|| {
                format!(
                    "Failed to copy '{:?}' to '{:?}'",
                    entry.path(),
                    target
                )
            })?;
        }
    }
    Ok(())
}

pub async fn install_packed_plugin(
    packed_file_path: &str,
    plugins_dir: &str,
    temp_dir: &str,
    should_load: bool,
    _policy_country_code: &str,
    manager: Option<&crate::api::plugin::plugin::PluginManager>,
) -> Result<PluginInstallResult> {
    let (manifest, temp_plugin_dir) = unpack_and_read_manifest(packed_file_path, temp_dir).await?;

    let cleanup = || async {
        let _ = tokio::fs::remove_dir_all(&temp_plugin_dir).await;
    };

    if manifest.manifest_version != CURRENT_MANIFEST_VERSION {
        cleanup().await;
        return Ok(PluginInstallResult {
            status: PluginInstallStatus::Failed,
            plugin_id: manifest.id,
            error: Some(format!(
                "Manifest version mismatch: Expected {}, got {}",
                CURRENT_MANIFEST_VERSION, manifest.manifest_version
            )),
        });
    }

    // Country restrictions removed - all plugins available to all countries
    // No country code checking needed - plugins install regardless of location

    if let Some(plugin_mgr) = manager {
        if let Some(plugin_type) = get_plugin_type_from_string(manifest.plugin_type()) {
            if plugin_mgr.is_plugin_loaded(&manifest.id, plugin_type).await {
                cleanup().await;
                return Ok(PluginInstallResult {
                    status: PluginInstallStatus::PluginLoaded,
                    plugin_id: manifest.id,
                    error: Some("Plugin is currently loaded".to_string()),
                });
            }
        }
    }

    let install_res = install_plugin(&temp_plugin_dir, &manifest, plugins_dir).await;
    cleanup().await;

    let (plugin_id, status) = install_res?;

    if should_load {
        if let Some(plugin_mgr) = manager {
            let plugin_type = get_plugin_type_from_string(manifest.plugin_type())
                .ok_or_else(|| anyhow::anyhow!("Unknown type: {}", manifest.plugin_type()))?;

            let plugin_path = format!("{}/{}/plugin.wasm", plugins_dir, plugin_id);

            plugin_mgr
                .load_plugin_from_path(&plugin_id, plugin_type, &plugin_path)
                .await
                .map_err(|e| anyhow::anyhow!("Failed to load: {}", e))?;
        }
    }

    Ok(PluginInstallResult {
        status,
        plugin_id,
        error: None,
    })
}

fn unpack_zip(archive_path: &str, output_folder: &str) -> Result<()> {
    let file = File::open(archive_path)
        .with_context(|| format!("Failed to open zip archive '{}'", archive_path))?;
    let mut zip_archive = zip::ZipArchive::new(file)
        .with_context(|| format!("Failed to parse zip archive '{}'", archive_path))?;

    for i in 0..zip_archive.len() {
        let mut file = zip_archive.by_index(i)?;
        let outpath = match file.enclosed_name() {
            Some(path) => std::path::Path::new(output_folder).join(path),
            None => continue,
        };

        if (*file.name()).ends_with('/') {
            std::fs::create_dir_all(&outpath)?;
        } else {
            if let Some(p) = outpath.parent() {
                if !p.exists() {
                    std::fs::create_dir_all(p)?;
                }
            }
            let mut outfile = File::create(&outpath)?;
            std::io::copy(&mut file, &mut outfile)?;
        }
    }
    Ok(())
}

pub async fn unpack_plugin(
    archive_path: &str,
    output_folder: &str,
    expected_extension: Option<&str>,
) -> Result<()> {
    if archive_path.is_empty() || output_folder.is_empty() {
        anyhow::bail!("Archive path and output folder cannot be empty");
    }

    let path = std::path::Path::new(archive_path);
    if !path.exists() {
        anyhow::bail!("Archive file not found: {}", archive_path);
    }

    if let Some(expected_ext) = expected_extension {
        match path.extension() {
            Some(ext) => {
                let ext_str = ext.to_string_lossy().to_lowercase();
                let exp_str = expected_ext.to_lowercase();
                if ext_str != exp_str && ext_str != "bex" && ext_str != "sflx" && ext_str != "spotiflac-ext" {
                    anyhow::bail!(
                        "Expected .{} extension, got .{}",
                        expected_ext,
                        ext.to_string_lossy()
                    );
                }
            }
            None => anyhow::bail!("Expected plugin extension, got none"),
        }
    } else {
        match path.extension() {
            Some(ext) => {
                let ext_str = ext.to_string_lossy().to_lowercase();
                if ext_str != "bex" && ext_str != "sflx" && ext_str != "spotiflac-ext" {
                    anyhow::bail!(
                        "Expected .bex, .sflx or .spotiflac-ext extension, got .{}",
                        ext.to_string_lossy()
                    );
                }
            }
            None => anyhow::bail!("Expected plugin extension, got none"),
        }
    }

    tokio::fs::create_dir_all(output_folder)
        .await
        .with_context(|| format!("Failed to create directory '{}'", output_folder))?;

    let archive_path_owned = archive_path.to_string();
    let output_folder_owned = output_folder.to_string();
    tokio::task::spawn_blocking(move || -> Result<()> {
        let is_zip = if let Ok(mut f) = File::open(&archive_path_owned) {
            let mut magic = [0u8; 4];
            if f.read_exact(&mut magic).is_ok() {
                magic == [0x50, 0x4B, 0x03, 0x04] || magic == [0x50, 0x4B, 0x05, 0x06]
            } else {
                false
            }
        } else {
            false
        };

        if is_zip {
            unpack_zip(&archive_path_owned, &output_folder_owned)?;
        } else {
            let try_zstd = || -> Result<()> {
                let file = File::open(&archive_path_owned)?;
                let decoder = Decoder::new(BufReader::new(file))?;
                Archive::new(decoder).unpack(&output_folder_owned)?;
                Ok(())
            };
            if let Err(zstd_err) = try_zstd() {
                unpack_zip(&archive_path_owned, &output_folder_owned).with_context(|| {
                    format!(
                        "Failed to unpack archive (zstd error: {}; zip fallback also failed)",
                        zstd_err
                    )
                })?;
            }
        }
        Ok(())
    })
    .await??;

    Ok(())
}

pub fn scan_bex_files(directory: &str) -> Result<Vec<String>> {
    let mut files = Vec::new();
    let paths = std::fs::read_dir(directory)
        .with_context(|| format!("Failed to read directory '{}'", directory))?;

    for path in paths {
        let path = path.with_context(|| "Failed to read entry")?.path();
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            let lower_ext = ext.to_lowercase();
            if lower_ext == "bex" || lower_ext == "sflx" || lower_ext == "spotiflac-ext" {
                if let Some(path_str) = path.to_str() {
                    files.push(path_str.to_string());
                }
            }
        }
    }
    Ok(files)
}

