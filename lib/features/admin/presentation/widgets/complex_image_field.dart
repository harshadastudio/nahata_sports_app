import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_sports_complex.dart';
import '../theme/admin_theme.dart';

/// The image slot on the sports complex form.
///
/// Picking a file uploads it straight away via
/// `POST /sports-complexes/upload-image` and reports the URL the server stored
/// — that URL, not the file, is what the create/update payload carries. Doing
/// the upload here rather than on submit means the admin sees a failure (a file
/// too large, a rejected type) while they can still fix it, instead of losing a
/// filled-in form to a save error.
///
/// Note on drag & drop: Flutter has no built-in OS file-drop support, and the
/// project carries no desktop-drop package. The zone below is the full browse /
/// preview / replace / remove flow; wiring a real drop target would mean adding
/// `desktop_drop` and calling [_handlePicked] from its `onDragDone`.
class ComplexImageField extends StatefulWidget {
  const ComplexImageField({
    super.key,
    required this.imageUrl,
    required this.onChanged,
    required this.onUpload,
    this.onServerDelete,
    this.enabled = true,
  });

  /// The stored image value — what the payload will send.
  final String? imageUrl;

  /// Called with the new stored value, or null when the image is removed.
  final ValueChanged<String?> onChanged;

  /// Uploads the file and resolves to the stored URL. Throws on failure.
  final Future<String> Function(String path, {String? filename}) onUpload;

  /// `DELETE /sports-complexes/delete-image` — offered only where the image
  /// already lives on the server, i.e. the edit dialog.
  final Future<void> Function(String imageUrl)? onServerDelete;

  final bool enabled;

  /// The spec's ceiling, in bytes.
  static const int maxBytes = 5 * 1024 * 1024;

  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  @override
  State<ComplexImageField> createState() => _ComplexImageFieldState();
}

class _ComplexImageFieldState extends State<ComplexImageField> {
  final ImagePicker _picker = ImagePicker();

  /// Shown while the upload is in flight, so the admin sees their own file
  /// rather than an empty box.
  File? _localPreview;

  bool _uploading = false;
  bool _deleting = false;
  String? _error;

  bool get _busy => _uploading || _deleting;
  bool get _hasImage =>
      _localPreview != null || (widget.imageUrl ?? '').trim().isNotEmpty;

  Future<void> _browse() async {
    if (!widget.enabled || _busy) return;

    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    await _handlePicked(File(file.path), file.name);
  }

  /// Validates then uploads. Kept separate from [_browse] so a future drop
  /// target can reuse exactly this path.
  Future<void> _handlePicked(File file, String displayName) async {
    final extension = displayName.contains('.')
        ? displayName.split('.').last.toLowerCase()
        : file.path.split('.').last.toLowerCase();

    if (!ComplexImageField.allowedExtensions.contains(extension)) {
      setState(() => _error = 'Use a JPG, PNG or WEBP image.');
      AdminLog.ui('Image rejected — unsupported type .$extension');
      return;
    }

    final length = await file.length();
    if (length > ComplexImageField.maxBytes) {
      final mb = (length / (1024 * 1024)).toStringAsFixed(1);
      setState(() => _error = 'That image is ${mb}MB. The limit is 5MB.');
      AdminLog.ui('Image rejected — $mb MB exceeds the 5MB limit');
      return;
    }

    setState(() {
      _localPreview = file;
      _uploading = true;
      _error = null;
    });

    try {
      final url = await widget.onUpload(file.path, filename: displayName);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPreview = null;
      });
      widget.onChanged(url);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _localPreview = null;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        'Complex image upload crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _uploading = false;
        _localPreview = null;
        _error = 'Could not upload that image. Please try again.';
      });
    }
  }

  /// Clears the field without touching the server — the stored file stays put
  /// until the admin explicitly deletes it.
  void _remove() {
    if (_busy) return;
    AdminLog.ui('Complex image removed from the form');
    setState(() {
      _localPreview = null;
      _error = null;
    });
    widget.onChanged(null);
  }

  Future<void> _deleteFromServer() async {
    final url = (widget.imageUrl ?? '').trim();
    final delete = widget.onServerDelete;
    if (url.isEmpty || delete == null || _busy) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await delete(url);
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _localPreview = null;
      });
      widget.onChanged(null);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        'Complex image delete crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _deleting = false;
        _error = 'Could not delete that image. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasImage) _preview(tokens) else _dropZone(tokens),
        if (_error != null) ...[
          const SizedBox(height: AdminTokens.space3),
          _ErrorNote(message: _error!),
        ],
      ],
    );
  }

  /// The empty state: a dashed browse target.
  Widget _dropZone(AdminTokens tokens) {
    return _HoverZone(
      enabled: widget.enabled && !_busy,
      onTap: _browse,
      builder: (hovered) {
        final accent = hovered ? tokens.accent : tokens.borderStrong;

        return DottedBorderBox(
          color: accent,
          radius: AdminTokens.radiusLg,
          child: Container(
            height: 176,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovered ? tokens.accentSoft : tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.accent.withValues(
                      alpha: hovered ? 0.18 : 0.10,
                    ),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 24,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(height: AdminTokens.space3),
                Text(
                  'Browse for an image',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'JPG, PNG or WEBP · up to 5MB',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _preview(AdminTokens tokens) {
    final local = _localPreview;
    final resolved = resolveMediaUrl(widget.imageUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
          child: Stack(
            children: [
              SizedBox(
                height: 176,
                width: double.infinity,
                child: local != null
                    ? Image.file(local, fit: BoxFit.cover)
                    : (resolved == null
                          ? ColoredBox(color: tokens.surfaceAlt)
                          : CachedNetworkImage(
                              imageUrl: resolved,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  ColoredBox(color: tokens.surfaceAlt),
                              // A broken URL reads as "no image" rather than a
                              // broken-image glyph.
                              errorWidget: (_, __, ___) => Container(
                                color: tokens.surfaceAlt,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 26,
                                  color: tokens.textMuted,
                                ),
                              ),
                            )),
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space3),
                          Text(
                            _uploading ? 'Uploading…' : 'Deleting…',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AdminTokens.space3),
        Wrap(
          spacing: AdminTokens.space3,
          runSpacing: AdminTokens.space2,
          children: [
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy ? _browse : null,
              icon: const Icon(Icons.swap_horiz_rounded, size: 17),
              label: const Text('Replace'),
            ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy ? _remove : null,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Remove'),
            ),
            if (widget.onServerDelete != null &&
                (widget.imageUrl ?? '').trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: widget.enabled && !_busy ? _deleteFromServer : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.danger,
                  side: BorderSide(
                    color: tokens.danger.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        Text(
          'Remove clears it from this form. Delete image also removes the '
          'file from the server.',
          style: TextStyle(color: tokens.textMuted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}

/// A hover-aware tap target — the console's cards use the same idiom.
class _HoverZone extends StatefulWidget {
  const _HoverZone({
    required this.builder,
    required this.onTap,
    required this.enabled,
  });

  final Widget Function(bool hovered) builder;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_HoverZone> createState() => _HoverZoneState();
}

class _HoverZoneState extends State<_HoverZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: widget.builder(_hovered && widget.enabled),
      ),
    );
  }
}

/// A dashed rounded border.
///
/// Hand-painted because the project has no dotted-border package, and a solid
/// border would not read as a drop target.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = AdminTokens.radiusLg,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1.4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        dash: dash,
        gap: gap,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height).deflate(strokeWidth / 2),
        Radius.circular(radius),
      ),
    );

    // Walk the outline, drawing `dash` then skipping `gap`.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.danger,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
