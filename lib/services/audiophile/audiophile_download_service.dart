import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:voidmusic/services/audiophile/monochrome_api_client.dart';
import 'package:voidmusic/services/audiophile/zarz_moe_client.dart';

enum DownloadTaskStatus {
  queued,
  downloading,
  decrypting,
  completed,
  failed,
}

class AudiophileDownloadTask {
  final String id;
  final String trackId;
  final String title;
  final String artist;
  final String album;
  final String thumbnailUrl;
  final String format; // flac, alac, dsd, etc.
  final LosslessQuality quality;
  final String provider;

  DownloadTaskStatus status;
  double progress; // 0.0 to 1.0
  String? filePath;
  String? errorMessage;
  int bytesDownloaded;
  int totalBytes;

  AudiophileDownloadTask({
    required this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnailUrl,
    required this.format,
    required this.quality,
    required this.provider,
    this.status = DownloadTaskStatus.queued,
    this.progress = 0.0,
    this.filePath,
    this.errorMessage,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnailUrl': thumbnailUrl,
        'format': format,
        'quality': quality.id,
        'provider': provider,
        'status': status.name,
        'progress': progress,
        'filePath': filePath,
        'errorMessage': errorMessage,
        'bytesDownloaded': bytesDownloaded,
        'totalBytes': totalBytes,
      };
}

/// Managing high-quality Audiophile Downloads (FLAC, HD FLAC, Ultra FLAC, DSD, ALAC)
class AudiophileDownloadService {
  static final AudiophileDownloadService _instance =
      AudiophileDownloadService._internal();
  factory AudiophileDownloadService() => _instance;
  AudiophileDownloadService._internal();

  final MonochromeApiClient _monoClient = MonochromeApiClient();
  final ZarzMoeClient _zarzClient = ZarzMoeClient();
  final Map<String, AudiophileDownloadTask> _tasks = {};
  final _tasksController =
      StreamController<List<AudiophileDownloadTask>>.broadcast();

  bool _isProcessing = false;

  Stream<List<AudiophileDownloadTask>> get tasksStream =>
      _tasksController.stream;
  List<AudiophileDownloadTask> get allTasks => _tasks.values.toList();
  List<AudiophileDownloadTask> get activeQueue => _tasks.values
      .where((t) =>
          t.status == DownloadTaskStatus.queued ||
          t.status == DownloadTaskStatus.downloading ||
          t.status == DownloadTaskStatus.decrypting)
      .toList();
  List<AudiophileDownloadTask> get completedTasks => _tasks.values
      .where((t) => t.status == DownloadTaskStatus.completed)
      .toList();

  /// Enqueue a track for FLAC/Lossless download
  Future<AudiophileDownloadTask> enqueueDownload({
    required String trackId,
    required String title,
    required String artist,
    required String album,
    required String thumbnailUrl,
    String format = 'flac',
    LosslessQuality quality = LosslessQuality.losslessFlac,
    String provider = 'deezer',
  }) async {
    final taskId = '${provider}_${trackId}_${DateTime.now().millisecondsSinceEpoch}';
    final task = AudiophileDownloadTask(
      id: taskId,
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbnailUrl,
      format: format,
      quality: quality,
      provider: provider,
    );

    _tasks[taskId] = task;
    _notifyListeners();

    _processQueue();
    return task;
  }

  void _notifyListeners() {
    _tasksController.add(_tasks.values.toList());
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (true) {
        final pending = _tasks.values.firstWhere(
          (t) => t.status == DownloadTaskStatus.queued,
          orElse: () => AudiophileDownloadTask(
            id: '',
            trackId: '',
            title: '',
            artist: '',
            album: '',
            thumbnailUrl: '',
            format: '',
            quality: LosslessQuality.losslessFlac,
            provider: '',
            status: DownloadTaskStatus.failed,
          ),
        );

        if (pending.id.isEmpty) break;

        await _executeDownload(pending);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeDownload(AudiophileDownloadTask task) async {
    task.status = DownloadTaskStatus.downloading;
    task.progress = 0.05;
    _notifyListeners();

    try {
      // ── Step 1: Resolve stream URL via ZarzMoeClient (primary) ──────────
      // This mirrors the plugin JS: signedTicket → POST /dl/dzr → download_url
      String downloadUrl = '';
      String codec = task.format.isNotEmpty ? task.format : 'flac';
      bool requiresDecrypt = false;
      String? encryptionKey;

      final provider = task.provider
          .replaceAll('audiophile.', '')
          .replaceAll('audiophile-', '');

      log('Resolving lossless stream via ZarzMoeClient for ${task.title} ($provider)',
          name: 'AudiophileDownloadService');

      final descriptor = await _zarzClient.getDownloadDescriptor(
        provider: provider,
        trackId: task.trackId,
      );

      if (descriptor.success && descriptor.downloadUrl.isNotEmpty) {
        downloadUrl = descriptor.downloadUrl;
        codec = descriptor.format.isNotEmpty ? descriptor.format : 'flac';
        requiresDecrypt = descriptor.requiresClientDecryption;
        encryptionKey = descriptor.encryptionKey;

        // Audiophile strict check — reject non-lossless formats
        if (!descriptor.isLossless) {
          throw Exception(
              'Audiophile mode: rejected non-lossless format "${descriptor.format}" from zarz.moe. Only FLAC/ALAC/DSD/WAV allowed.');
        }

        log('ZarzMoeClient resolved: ${descriptor.qualityLabel} → $downloadUrl',
            name: 'AudiophileDownloadService');
      } else {
        // ── Step 1b: Fallback to Monochrome API ──────────────────────────
        log('ZarzMoe failed (${descriptor.errorMessage ?? "no URL"}), trying Monochrome...',
            name: 'AudiophileDownloadService');

        final streamInfo = await _monoClient.getStreamUrl(
          task.trackId,
          minQuality: task.quality,
        );

        if (streamInfo == null || streamInfo.url.isEmpty) {
          throw Exception(
              'No lossless stream URL found for "${task.title}". '
              'ZarzMoe: ${descriptor.errorMessage ?? "no response"}. '
              'Monochrome: no stream available.');
        }

        // Strict lossless format enforcement
        if (!streamInfo.isLossless) {
          throw Exception(
              'Audiophile mode: rejected non-lossless format "${streamInfo.codec}" from Monochrome. Only FLAC/ALAC/DSD/WAV allowed.');
        }

        downloadUrl = streamInfo.url;
        codec = streamInfo.codec.isNotEmpty ? streamInfo.codec : 'flac';
        requiresDecrypt = streamInfo.encryptionKey != null &&
            streamInfo.encryptionKey!.isNotEmpty;
        encryptionKey = streamInfo.encryptionKey;

        log('Monochrome resolved: ${streamInfo.formatLabel} → $downloadUrl',
            name: 'AudiophileDownloadService');
      }

      // ── Step 2: Prepare download destination ───────────────────────────
      task.progress = 0.12;
      _notifyListeners();

      final downloadDir = await _getAudiophileDownloadDirectory();
      final sanitizedTitle =
          task.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final sanitizedArtist =
          task.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = codec.toLowerCase().split('/').first.split('+').first.trim();
      final fileName = '$sanitizedArtist - $sanitizedTitle.${ext.isNotEmpty ? ext : "flac"}';
      final savePath = p.join(downloadDir.path, fileName);

      // ── Step 3: Download stream bytes ──────────────────────────────────
      task.progress = 0.15;
      _notifyListeners();

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'SpotiFLAC-Mobile/5.0';
      request.headers['Accept'] = 'audio/flac, audio/*';

      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode} when downloading stream for "${task.title}"');
      }

      final contentLength = response.contentLength ?? 0;
      task.totalBytes = contentLength;

      // Collect all bytes (needed for Blowfish decryption over the full file)
      final allBytes = <int>[];
      await for (final chunk in response.stream) {
        allBytes.addAll(chunk);
        task.bytesDownloaded = allBytes.length;
        if (contentLength > 0) {
          task.progress = 0.15 + (allBytes.length / contentLength) * 0.65;
        }
        _notifyListeners();
      }

      task.progress = 0.80;
      _notifyListeners();

      // ── Step 4: Decrypt if needed (Blowfish CBC for Deezer) ────────────
      Uint8List finalBytes;
      if (requiresDecrypt && provider.contains('deezer')) {
        task.status = DownloadTaskStatus.decrypting;
        task.progress = 0.85;
        _notifyListeners();

        log('Applying Blowfish CBC decryption for ${task.title}... (key: ${encryptionKey ?? "auto"})',
            name: 'AudiophileDownloadService');

        // Use ZarzMoeClient.decryptDeezerStream — real Blowfish CBC
        // matching the plugin JS decryptDownloadedFile() exactly
        final cleanId = task.trackId
            .replaceAll('deezer:', '')
            .replaceAll('audiophile.', '')
            .split(':')
            .last;
        finalBytes = ZarzMoeClient.decryptDeezerStream(
            Uint8List.fromList(allBytes), cleanId);

        task.progress = 0.92;
        _notifyListeners();
      } else {
        finalBytes = Uint8List.fromList(allBytes);
      }

      // ── Step 5: Save file ──────────────────────────────────────────────
      final file = File(savePath);
      await file.writeAsBytes(finalBytes, flush: true);

      task.status = DownloadTaskStatus.completed;
      task.progress = 1.0;
      task.filePath = savePath;
      log('✓ Downloaded Audiophile track: $savePath (${(finalBytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
          name: 'AudiophileDownloadService');
    } catch (e) {
      log('✗ Download failed for "${task.title}": $e',
          name: 'AudiophileDownloadService');
      task.status = DownloadTaskStatus.failed;
      task.errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _notifyListeners();
    }
  }

  Future<Directory> _getAudiophileDownloadDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'VoidMusic', 'AudiophileFLAC'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  void cancelTask(String taskId) {
    final task = _tasks[taskId];
    if (task != null &&
        (task.status == DownloadTaskStatus.queued ||
            task.status == DownloadTaskStatus.downloading)) {
      task.status = DownloadTaskStatus.failed;
      task.errorMessage = 'Cancelled by user';
      _notifyListeners();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((_, t) => t.status == DownloadTaskStatus.completed);
    _notifyListeners();
  }
}
