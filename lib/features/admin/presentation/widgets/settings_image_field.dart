import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/app_settings.dart';
import '../theme/admin_theme.dart';
import 'admin_form_fields.dart';

/// The logo / favicon slot on the branding card.
///
/// Picking a file uploads it straight away and reports the URL the server
/// stored — that URL, not the file, is what branding carries. Doing the upload
/// here rather than on submit means the admin sees a failure (a file too
/// large, a rejected type) while they can still fix it.
///
/// The upload itself is indeterminate: the app's HTTP client posts the whole
/// multipart body in one call and exposes no byte counter, so a percentage bar
/// here would be an invented number. The bar animates while the request is in
/// flight and stops when it resolves.
class SettingsImageField extends StatefulWidget {
  const SettingsImageField({
    super.key,
    required this.kind,
    required this.imageUrl,
    required this.onChanged,
    required this.onUpload,
    this.uploading = false,
    this.enabled = true,
  });

  final SettingsImageKind kind;

  /// The stored URL — what branding will send.
  final String? imageUrl;

  /// Called with the new stored value, or null when the image is cleared.
  final ValueChanged<String?> onChanged;

  /// Uploads the file and resolves to the stored URL. Throws on failure.
  final Future<String> Function(String path, {String? filename}) onUpload;

  /// True while the controller is running this kind's upload.
  final bool uploading;

  final bool enabled;

  @override
  State<SettingsImageField> createState() => _SettingsImageFieldState();
}

class _SettingsImageFieldState extends State<SettingsImageField> {
  final ImagePicker _picker = ImagePicker();

  /// Shown while the upload is in flight, so the admin sees their own file
  /// rather than an empty box.
  File? _localPreview;

  bool _working = false;
  String? _error;

  bool get _busy => _working || widget.uploading;

  bool get _hasImage =>
      _localPreview != null || (widget.imageUrl ?? '').trim().isNotEmpty;

  /// A favicon is a small square; a logo is wide. Sizing the slot to match
  /// means neither is shown in a box that misrepresents it.
  double get _slotHeight => widget.kind == SettingsImageKind.favicon ? 72 : 96;

  Future<void> _browse() async {
    if (!widget.enabled || _busy) return;

    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    await _handlePicked(File(file.path), file.name);
  }

  Future<void> _handlePicked(File file, String displayName) async {
    final extension = displayName.contains('.')
        ? displayName.split('.').last.toLowerCase()
        : file.path.split('.').last.toLowerCase();

    if (!SettingsValidation.allowedImageExtensions.contains(extension)) {
      setState(() => _error = 'Use a JPG, PNG or WEBP image.');
      AdminLog.ui('${widget.kind.label} rejected — unsupported type .$extension');
      return;
    }

    final length = await file.length();
    if (length > SettingsValidation.maxImageBytes) {
      final mb = (length / (1024 * 1024)).toStringAsFixed(1);
      setState(
        () => _error =
            'That image is ${mb}MB. The limit is '
            '${SettingsValidation.maxImageMegabytes}MB.',
      );
      AdminLog.ui('${widget.kind.label} rejected — $mb MB is over the limit');
      return;
    }

    setState(() {
      _localPreview = file;
      _working = true;
      _error = null;
    });

    try {
      final url = await widget.onUpload(file.path, filename: displayName);
      if (!mounted) return;
      setState(() {
        _working = false;
        // Dropped only once the stored URL is in: until then the local file is
        // the only thing that can be shown.
        _localPreview = null;
      });
      widget.onChanged(url);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _localPreview = null;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        '${widget.kind.label} upload crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _working = false;
        _localPreview = null;
        _error = 'Could not upload that image. Please try again.';
      });
    }
  }

  /// Clears the field. The stored file stays on the server — branding simply
  /// stops pointing at it once the card is saved.
  void _remove() {
    if (_busy) return;
    AdminLog.ui('${widget.kind.label} cleared from the form');
    setState(() {
      _localPreview = null;
      _error = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(widget.kind.label),
        const SizedBox(height: AdminTokens.space2),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space3),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(
              color: _error != null ? tokens.danger : tokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _slotHeight,
                child: _Preview(
                  kind: widget.kind,
                  local: _localPreview,
                  url: widget.imageUrl,
                  busy: _busy,
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: AdminTokens.space3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                  child: const SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Text(
                  'Uploading…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
              const SizedBox(height: AdminTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.enabled && !_busy ? _browse : null,
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      label: Text(
                        _hasImage ? 'Replace' : 'Upload',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                        side: BorderSide(color: tokens.border),
                        padding: const EdgeInsets.symmetric(
                          vertical: AdminTokens.space2 + 2,
                        ),
                      ),
                    ),
                  ),
                  if (_hasImage) ...[
                    const SizedBox(width: AdminTokens.space2),
                    IconButton(
                      onPressed: widget.enabled && !_busy ? _remove : null,
                      icon: const Icon(Icons.close_rounded, size: 17),
                      color: tokens.textMuted,
                      tooltip: 'Remove ${widget.kind.label.toLowerCase()}',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(color: tokens.danger, fontSize: 11.5),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            'JPG, PNG or WEBP, up to '
            '${SettingsValidation.maxImageMegabytes}MB.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.kind,
    required this.local,
    required this.url,
    required this.busy,
  });

  final SettingsImageKind kind;
  final File? local;
  final String? url;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final stored = (url ?? '').trim();

    Widget frame(Widget child) {
      return Container(
        decoration: BoxDecoration(
          // White behind the image: a logo is usually drawn for a light
          // background and would disappear on the dark canvas.
          color: Colors.white,
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          border: Border.all(color: tokens.border),
        ),
        padding: const EdgeInsets.all(AdminTokens.space2),
        child: Opacity(opacity: busy ? 0.55 : 1, child: child),
      );
    }

    if (local != null) {
      return frame(
        Image.file(
          local!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _Placeholder(kind: kind),
        ),
      );
    }

    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      return frame(
        CachedNetworkImage(
          imageUrl: stored,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => _Placeholder(kind: kind),
        ),
      );
    }

    if (stored.isNotEmpty) {
      // A stored value that is not a URL — a path the app cannot resolve on
      // its own. It is shown as text rather than as a broken image.
      return frame(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space2),
            child: Text(
              stored,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return _Placeholder(kind: kind);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.kind});

  final SettingsImageKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kind == SettingsImageKind.logo
                ? Icons.image_outlined
                : Icons.star_outline_rounded,
            size: 22,
            color: tokens.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            'No ${kind.label.toLowerCase()}',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}