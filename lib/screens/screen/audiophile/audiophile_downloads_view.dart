import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:voidmusic/blocs/audiophile/audiophile_cubit.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/screens/widgets/audiophile_badge_widget.dart';
import 'package:voidmusic/services/audiophile/audiophile_download_service.dart';

class AudiophileDownloadsView extends StatelessWidget {
  const AudiophileDownloadsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudiophileCubit, AudiophileState>(
      builder: (context, state) {
        final tasks = state.downloadQueue;
        final activeTasks = tasks
            .where((t) =>
                t.status == DownloadTaskStatus.queued ||
                t.status == DownloadTaskStatus.downloading ||
                t.status == DownloadTaskStatus.decrypting)
            .toList();
        final completedTasks = tasks
            .where((t) => t.status == DownloadTaskStatus.completed)
            .toList();
        final failedTasks = tasks
            .where((t) => t.status == DownloadTaskStatus.failed)
            .toList();

        if (tasks.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Active Downloads Section ─────────────────────────────────────
            if (activeTasks.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'ACTIVE FLAC DOWNLOADS',
                count: activeTasks.length,
                icon: MingCute.download_2_line,
                color: AppTheme.accentColor(context),
              ),
              const SizedBox(height: 12),
              ...activeTasks.map((task) => _buildActiveTaskTile(context, task)),
              const SizedBox(height: 24),
            ],

            // ── Completed Downloads Section ──────────────────────────────────
            if (completedTasks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(
                    context,
                    title: 'COMPLETED AUDIOPHILE TRACKS',
                    count: completedTasks.length,
                    icon: MingCute.check_circle_line,
                    color: Colors.green,
                  ),
                  TextButton.icon(
                    onPressed: () {
                      context
                          .read<AudiophileCubit>()
                          .clearCompletedDownloads();
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...completedTasks
                  .map((task) => _buildCompletedTaskTile(context, task)),
              const SizedBox(height: 24),
            ],

            // ── Failed Section ───────────────────────────────────────────────
            if (failedTasks.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'FAILED DOWNLOADS',
                count: failedTasks.length,
                icon: MingCute.close_circle_line,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              ...failedTasks
                  .map((task) => _buildFailedTaskTile(context, task)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentColor(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                MingCute.download_3_line,
                size: 48,
                color: AppTheme.accentColor(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Audiophile Downloads',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FLAC 16-bit, Hi-Res 24-bit, and Studio Master downloads will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTaskTile(
      BuildContext context, AudiophileDownloadTask task) {
    final statusText = task.status == DownloadTaskStatus.decrypting
        ? 'Decrypting Blowfish stream...'
        : 'Downloading ${(task.progress * 100).toStringAsFixed(0)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  task.thumbnailUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${task.artist} • ${task.provider.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const AudiophileBadgeWidget(
                label: 'FLAC 24-BIT',
                isHiRes: true,
                fontSize: 8,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  context.read<AudiophileCubit>().cancelDownload(task.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: task.progress,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.accentColor(context)),
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: AppTheme.accentColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (task.totalBytes > 0)
                Text(
                  '${(task.bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} / ${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTaskTile(
      BuildContext context, AudiophileDownloadTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            task.thumbnailUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 44,
              height: 44,
              color: Colors.grey.shade900,
              child: const Icon(Icons.music_note, color: Colors.white54),
            ),
          ),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${task.artist} • Saved FLAC',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: const AudiophileBadgeWidget(
          label: 'FLAC',
          isHiRes: true,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildFailedTaskTile(
      BuildContext context, AudiophileDownloadTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          task.errorMessage ?? 'Download failed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }
}
