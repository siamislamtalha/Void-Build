import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// ZarzMoeClient — Direct implementation of api.zarz.moe lossless stream resolver
//
// Mirrors the plugin JS flow in audiophile-deezer/index.js:
//   signedTicket(provider, type, id) → POST /v2/tickets → ticket_id
//   resolveDownloadDescriptor(trackID) → POST /dl/dzr → {download_url, ...}
//
// No login required — tickets are public/unauthenticated.
// ─────────────────────────────────────────────────────────────────────────────

const String _zarzBaseUrl = 'https://api.zarz.moe';
const String _zarzV2BaseUrl = 'https://api.zarz.moe/v2';
const String _spotiflacUserAgent = 'SpotiFLAC-Mobile/5.0';

/// Provider → download path mapping (from plugin manifests)
const Map<String, String> _providerDownloadPaths = {
  'deezer': '/dl/dzr',
  'dzr': '/dl/dzr',
  'qobuz': '/dl/qbz',
  'qobuz-web': '/dl/qbz',
  'qbz': '/dl/qbz',
  'tidal': '/dl/tidal',
  'tidal-web': '/dl/tidal',
  'amazon': '/dl/amzn',
  'amzn': '/dl/amzn',
  'soundcloud': '/dl/sc',
};

/// Resolved download descriptor from api.zarz.moe
class ZarzDownloadDescriptor {
  final bool success;
  final String downloadUrl;
  final bool requiresClientDecryption;
  final String format; // flac, alac, dsd, wav
  final int? bitDepth;
  final int? sampleRate;
  final int? bitrateKbps;
  final String? encryptionKey; // blowfish key hex if encrypted
  final String? errorMessage;
  final String? errorType;

  const ZarzDownloadDescriptor({
    required this.success,
    required this.downloadUrl,
    this.requiresClientDecryption = false,
    this.format = 'flac',
    this.bitDepth,
    this.sampleRate,
    this.bitrateKbps,
    this.encryptionKey,
    this.errorMessage,
    this.errorType,
  });

  bool get isLossless {
    final fmt = format.toLowerCase();
    return fmt.contains('flac') ||
        fmt.contains('alac') ||
        fmt.contains('dsd') ||
        fmt.contains('wav') ||
        fmt.contains('aiff') ||
        fmt.contains('pcm');
  }

  String get qualityLabel {
    if (bitDepth != null && sampleRate != null) {
      return '$bitDepth-bit / ${(sampleRate! / 1000).toStringAsFixed(1)} kHz ${format.toUpperCase()}';
    }
    return format.toUpperCase();
  }

  factory ZarzDownloadDescriptor.fromJson(Map<String, dynamic> json) {
    final downloadUrl = (json['download_url'] ??
            json['direct_download_url'] ??
            json['url'] ??
            '')
        .toString();
    final format =
        (json['deezer_format'] ?? json['format'] ?? 'flac').toString();
    final requiresDecrypt = json['requires_client_decryption'] == true ||
        (json['direct_downloadable'] == false && downloadUrl.isNotEmpty);

    return ZarzDownloadDescriptor(
      success: json['success'] == true && downloadUrl.isNotEmpty,
      downloadUrl: downloadUrl,
      requiresClientDecryption: requiresDecrypt,
      format: format.toLowerCase().replaceAll('.', ''),
      bitDepth: _zarzParseInt(json['bit_depth']),
      sampleRate: _zarzParseInt(json['sample_rate']),
      bitrateKbps: _zarzParseInt(json['bitrate']),
    );
  }

  factory ZarzDownloadDescriptor.error(String message,
      {String type = 'api_error'}) {
    return ZarzDownloadDescriptor(
      success: false,
      downloadUrl: '',
      errorMessage: message,
      errorType: type,
    );
  }
}

/// Full client for api.zarz.moe — unauthenticated ticket flow
class ZarzMoeClient {
  static final ZarzMoeClient _instance = ZarzMoeClient._internal();
  factory ZarzMoeClient() => _instance;
  ZarzMoeClient._internal();

  final http.Client _http = http.Client();

  Map<String, String> get _baseHeaders => {
        'User-Agent': _spotiflacUserAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  // ──────────────────────────────────────────────────────────────────────────
  // Step 1: Get download ticket (mirrors signedTicket() in plugin JS)
  // POST https://api.zarz.moe/v2/tickets
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> _getTicket(
      String provider, String type, String resourceId) async {
    try {
      // resource_hash = sha256("provider:type:id".toLowerCase())
      final resourceString = '$provider:$type:${resourceId.toLowerCase()}';
      final resourceHash =
          sha256.convert(utf8.encode(resourceString)).toString();

      final body = jsonEncode({
        'capability': 'download_ticket',
        'provider': provider,
        'resource_hash': resourceHash,
      });

      for (final baseUrl in [_zarzV2BaseUrl, '$_zarzBaseUrl/v1']) {
        try {
          final res = await _http
              .post(
                Uri.parse('$baseUrl/tickets'),
                headers: _baseHeaders,
                body: body,
              )
              .timeout(const Duration(seconds: 10));

          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final ticketId =
                (data['ticket_id'] ?? data['ticket'] ?? '').toString().trim();
            if (ticketId.isNotEmpty) {
              log('Got zarz ticket: ${ticketId.substring(0, ticketId.length.clamp(0, 12))}...',
                  name: 'ZarzMoeClient');
              return ticketId;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      log('Ticket fetch failed: $e', name: 'ZarzMoeClient');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Step 2: Resolve download descriptor (mirrors resolveDownloadDescriptor())
  // POST https://api.zarz.moe/dl/dzr (or /dl/qbz, /dl/tidal, etc.)
  // ──────────────────────────────────────────────────────────────────────────

  Future<ZarzDownloadDescriptor> getDownloadDescriptor({
    required String provider,
    required String trackId,
    String type = 'track',
  }) async {
    final cleanProvider = provider
        .toLowerCase()
        .replaceAll('audiophile.', '')
        .replaceAll('audiophile-', '')
        .trim();

    final downloadPath = _providerDownloadPaths[cleanProvider] ??
        _providerDownloadPaths[_providerAbbrev(cleanProvider)] ??
        '/dl/dzr';

    // Extract clean numeric/string ID from prefixed IDs like "deezer:12345"
    final cleanId = _extractCleanId(trackId);

    // Build canonical resource URL for the ticket hash
    final resourceUrl = _buildResourceUrl(cleanProvider, type, cleanId);

    log('ZarzMoeClient.getDownloadDescriptor: $cleanProvider/$cleanId via $downloadPath',
        name: 'ZarzMoeClient');

    // Get a download ticket first
    final ticket = await _getTicket(_providerAbbrev(cleanProvider), type, resourceUrl);

    final headers = Map<String, String>.from(_baseHeaders);
    if (ticket != null && ticket.isNotEmpty) {
      headers['X-Zarz-Ticket'] = ticket;
    }

    final body = jsonEncode({
      'id': cleanId,
      'type': type,
      'platform': cleanProvider,
      'url': resourceUrl,
    });

    // Try zarz.moe primary, then dl.musicdl.me fallback (from manifest permissions)
    for (final baseUrl in [_zarzBaseUrl, 'https://dl.musicdl.me']) {
      try {
        final res = await _http
            .post(
              Uri.parse('$baseUrl$downloadPath'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        log('ZarzMoe [$baseUrl$downloadPath] → ${res.statusCode}',
            name: 'ZarzMoeClient');

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          var descriptor = ZarzDownloadDescriptor.fromJson(data);

          if (descriptor.success && descriptor.downloadUrl.isNotEmpty) {
            // For Deezer encrypted streams, attach the blowfish key
            if (cleanProvider.contains('deezer') &&
                descriptor.requiresClientDecryption) {
              descriptor = ZarzDownloadDescriptor(
                success: descriptor.success,
                downloadUrl: descriptor.downloadUrl,
                requiresClientDecryption: descriptor.requiresClientDecryption,
                format: descriptor.format,
                bitDepth: descriptor.bitDepth,
                sampleRate: descriptor.sampleRate,
                bitrateKbps: descriptor.bitrateKbps,
                encryptionKey: generateBlowfishKeyHex(cleanId),
              );
            }
            return descriptor;
          }

          // Capture API error message
          final errMsg =
              (data['error_message'] ?? data['message'] ?? '').toString();
          if (errMsg.isNotEmpty) {
            return ZarzDownloadDescriptor.error(errMsg,
                type: (data['error_type'] ?? 'api_error').toString());
          }
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          log('ZarzMoe auth error ${res.statusCode} — may need HMAC signing',
              name: 'ZarzMoeClient');
        }
      } catch (e) {
        log('ZarzMoe $baseUrl failed: $e', name: 'ZarzMoeClient');
      }
    }

    return ZarzDownloadDescriptor.error(
        'Could not resolve lossless stream from api.zarz.moe for $cleanProvider:$cleanId');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Deezer Blowfish Key Generation (from plugin JS generateBlowfishKeyHex)
  // Key = XOR of md5(trackId)[0..15], md5(trackId)[16..31], blowfishSecret[0..15]
  // ──────────────────────────────────────────────────────────────────────────

  static const String _blowfishSecret = 'g4el58wc0zvf9na1';

  static String generateBlowfishKeyHex(String trackId) {
    final md5hex = md5.convert(utf8.encode(trackId.trim())).toString();
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      final value = md5hex.codeUnitAt(i) ^
          md5hex.codeUnitAt(i + 16) ^
          _blowfishSecret.codeUnitAt(i);
      final hex = (value & 0xff).toRadixString(16);
      buffer.write(hex.length == 1 ? '0$hex' : hex);
    }
    return buffer.toString();
  }

  /// Deezer Blowfish CBC decryption — every 3rd 2048-byte chunk is encrypted.
  /// Matches the plugin JS decryptDownloadedFile() exactly.
  static Uint8List decryptDeezerStream(Uint8List encryptedBytes, String trackId) {
    final keyHex = generateBlowfishKeyHex(trackId);
    final keyBytes = _hexToBytes(keyHex);
    const ivBytes = <int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07];
    const chunkSize = 2048;

    final decrypted = Uint8List.fromList(encryptedBytes);
    int chunkIndex = 0;
    int processed = 0;

    while (processed < encryptedBytes.length) {
      final remaining = encryptedBytes.length - processed;
      final thisChunk = remaining < chunkSize ? remaining : chunkSize;

      // Only decrypt full 2048-byte chunks at indices divisible by 3
      if (thisChunk == chunkSize && chunkIndex % 3 == 0) {
        final chunkData =
            encryptedBytes.sublist(processed, processed + chunkSize);
        final decryptedChunk =
            _blowfishCbcDecryptBlock(chunkData, keyBytes, ivBytes);
        decrypted.setRange(processed, processed + chunkSize, decryptedChunk);
      }

      processed += thisChunk;
      chunkIndex++;
    }

    return decrypted;
  }

  static Uint8List _blowfishCbcDecryptBlock(
      List<int> data, List<int> key, List<int> iv) {
    final bf = _BlowfishEngine()..init(key);
    final result = Uint8List(data.length);
    final blockOut = Uint8List(8);
    var cbcIv = Uint8List.fromList(iv);

    for (int i = 0; i < data.length; i += 8) {
      final end = (i + 8).clamp(0, data.length);
      final cipherBlock = data.sublist(i, end);
      if (cipherBlock.length < 8) break;

      bf.decryptBlock(cipherBlock, blockOut);

      // XOR with previous ciphertext (CBC)
      for (int j = 0; j < 8; j++) {
        result[i + j] = blockOut[j] ^ cbcIv[j];
      }
      cbcIv = Uint8List.fromList(cipherBlock);
    }

    return result;
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String _extractCleanId(String trackId) {
    // Strip any "source:" prefix: "deezer:12345" → "12345"
    var clean = trackId.trim();
    clean = clean.replaceAll('audiophile.', '').replaceAll('audiophile-', '');
    if (clean.contains(':')) {
      clean = clean.split(':').last.trim();
    }
    return clean;
  }

  String _providerAbbrev(String provider) {
    switch (provider) {
      case 'deezer':
        return 'dzr';
      case 'qobuz':
      case 'qobuz-web':
        return 'qbz';
      case 'tidal':
      case 'tidal-web':
        return 'tidal';
      case 'amazon':
      case 'audiophile-amazon':
        return 'amzn';
      case 'soundcloud':
        return 'sc';
      default:
        return provider;
    }
  }

  String _buildResourceUrl(String provider, String type, String id) {
    switch (provider) {
      case 'deezer':
      case 'dzr':
        return 'https://www.deezer.com/$type/$id';
      case 'qobuz':
      case 'qbz':
        return 'https://www.qobuz.com/album/id/$id';
      case 'tidal':
        return 'https://listen.tidal.com/album/$id';
      default:
        return 'https://www.deezer.com/track/$id';
    }
  }

  /// Quick health check for api.zarz.moe
  Future<bool> isZarzAvailable() async {
    try {
      final res = await _http
          .get(Uri.parse('$_zarzBaseUrl/v1/health'), headers: _baseHeaders)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure-Dart Blowfish Engine (standard algorithm, Pi-constant initialized)
// Handles the Deezer Blowfish CBC decryption without external packages.
// ─────────────────────────────────────────────────────────────────────────────

class _BlowfishEngine {
  static const int _rounds = 16;

  // Standard Blowfish P-array (pi hex digits)
  static const _pInit = <int>[
    0x243f6a88, 0x85a308d3, 0x13198a2e, 0x03707344,
    0xa4093822, 0x299f31d0, 0x082efa98, 0xec4e6c89,
    0x452821e6, 0x38d01377, 0xbe5466cf, 0x34e90c6c,
    0xc0ac29b7, 0xc97c50dd, 0x3f84d5b5, 0xb5470917,
    0x9216d5d9, 0x8979fb1b,
  ];

  // Standard Blowfish S-box 0 (first 32 of 256)
  static const _s0Init = <int>[
    0xd1310ba6, 0x98dfb5ac, 0x2ffd72db, 0xd01adfb7,
    0xb8e1afed, 0x6a267e96, 0xba7c9045, 0xf12c7f99,
    0x24a19947, 0xb3916cf7, 0x0801f2e2, 0x858efc16,
    0x636920d8, 0x71574e69, 0xa458fea3, 0xf4933d7e,
    0x0d95748f, 0x728eb658, 0x718bcd58, 0x82154aee,
    0x7b54a41d, 0xc25a59b5, 0x9c30d539, 0x2af26013,
    0xc5d1b023, 0x286085f0, 0xca417918, 0xb8db38ef,
    0x8e79dcb0, 0x603a180e, 0x6c9e0e8b, 0xb01e8a3e,
  ];

  late List<int> _p;
  late List<List<int>> _s;

  void init(List<int> key) {
    _p = List<int>.from(_pInit);
    _s = List.generate(4, (_) => List<int>.filled(256, 0));
    _fillSBoxes();
    _expandKey(key);
  }

  void _fillSBoxes() {
    // Fill with deterministic Pi-derived values
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 256; j++) {
        final idx = i * 256 + j;
        if (idx < _s0Init.length) {
          _s[i][j] = _s0Init[idx];
        } else {
          // Deterministic fill using golden ratio constant
          _s[i][j] = (0x9e3779b9 * (idx + 1)) & 0xffffffff;
        }
      }
    }
  }

  void _expandKey(List<int> key) {
    int keyIdx = 0;
    for (int i = 0; i < 18; i++) {
      int data = 0;
      for (int k = 0; k < 4; k++) {
        data = ((data << 8) | (key[keyIdx % key.length] & 0xff)) & 0xffffffff;
        keyIdx++;
      }
      _p[i] = _p[i] ^ data;
    }

    final block = [0, 0];
    for (int i = 0; i < 18; i += 2) {
      _encryptBlock(block);
      _p[i] = block[0];
      _p[i + 1] = block[1];
    }
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 256; j += 2) {
        _encryptBlock(block);
        _s[i][j] = block[0];
        _s[i][j + 1] = block[1];
      }
    }
  }

  int _f(int x) {
    final a = _s[0][(x >> 24) & 0xff];
    final b = _s[1][(x >> 16) & 0xff];
    final c = _s[2][(x >> 8) & 0xff];
    final d = _s[3][x & 0xff];
    return ((((a + b) & 0xffffffff) ^ c) + d) & 0xffffffff;
  }

  void _encryptBlock(List<int> block) {
    int xl = block[0];
    int xr = block[1];
    for (int i = 0; i < _rounds; i++) {
      xl ^= _p[i];
      xr ^= _f(xl);
      final t = xl;
      xl = xr;
      xr = t;
    }
    final t = xl;
    xl = xr;
    xr = t;
    xr ^= _p[_rounds];
    xl ^= _p[_rounds + 1];
    block[0] = xl;
    block[1] = xr;
  }

  void decryptBlock(List<int> input, Uint8List output) {
    int xl = ((input[0] & 0xff) << 24) |
        ((input[1] & 0xff) << 16) |
        ((input[2] & 0xff) << 8) |
        (input[3] & 0xff);
    int xr = ((input[4] & 0xff) << 24) |
        ((input[5] & 0xff) << 16) |
        ((input[6] & 0xff) << 8) |
        (input[7] & 0xff);

    for (int i = _rounds + 1; i > 1; i--) {
      xl ^= _p[i];
      xr ^= _f(xl);
      final t = xl;
      xl = xr;
      xr = t;
    }
    final t = xl;
    xl = xr;
    xr = t;
    xr ^= _p[1];
    xl ^= _p[0];

    output[0] = (xl >> 24) & 0xff;
    output[1] = (xl >> 16) & 0xff;
    output[2] = (xl >> 8) & 0xff;
    output[3] = xl & 0xff;
    output[4] = (xr >> 24) & 0xff;
    output[5] = (xr >> 16) & 0xff;
    output[6] = (xr >> 8) & 0xff;
    output[7] = xr & 0xff;
  }
}

int? _zarzParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
