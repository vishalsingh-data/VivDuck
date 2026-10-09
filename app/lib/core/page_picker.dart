import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// The pages of a scanned answer, in order: photographed one by one, picked
/// from the gallery, or a PDF. Shows a thumbnail per page with a way to
/// remove it, and keeps to the upload limits in contract 07.
class PagePicker extends StatefulWidget {
  final List<UploadPage> pages;
  final ValueChanged<List<UploadPage>> onChanged;
  final bool enabled;

  /// What is being scanned, e.g. "your handwritten answer".
  final String what;

  const PagePicker({
    super.key,
    required this.pages,
    required this.onChanged,
    required this.what,
    this.enabled = true,
  });

  @override
  State<PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<PagePicker> {
  String? _error;

  void _add(List<UploadPage> added) {
    if (added.isEmpty) return;
    final all = [...widget.pages, ...added];
    final total = all.fold<int>(0, (t, p) => t + p.bytes.length);
    final tooBig = added.where(
      (p) => p.bytes.length > (p.isPdf ? maxPdfBytes : maxPhotoBytes),
    );
    setState(() {
      _error = tooBig.isNotEmpty
          ? '${tooBig.first.name} is too large. Photos can be up to 5 MB and a PDF up to 10 MB.'
          : all.length > maxUploadPages
          ? 'Up to $maxUploadPages pages. Remove some, or combine them into one PDF.'
          : total > maxUploadBytes
          ? 'The pages add up to more than 15 MB. Use fewer or smaller pages.'
          : null;
    });
    if (_error == null) widget.onChanged(all);
  }

  Future<void> _camera() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2200,
        imageQuality: 85,
      );
      if (f != null) _add([await _fromXFile(f)]);
    } catch (_) {
      setState(() => _error = "Couldn't open the camera.");
    }
  }

  Future<void> _photos() async {
    try {
      // Resized and compressed like a camera shot, so phone photos fit.
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 2200,
        imageQuality: 85,
      );
      _add([for (final f in files) await _fromXFile(f)]);
    } catch (_) {
      setState(() => _error = "Couldn't open your photos.");
    }
  }

  Future<void> _pdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      _add([
        for (final f in files)
          UploadPage(await f.readAsBytes(), 'application/pdf', f.name),
      ]);
    } catch (_) {
      setState(() => _error = "Couldn't open that file.");
    }
  }

  static Future<UploadPage> _fromXFile(XFile f) async {
    final name = f.name.toLowerCase();
    final mime =
        f.mimeType ?? (name.endsWith('.png') ? 'image/png' : 'image/jpeg');
    return UploadPage(await f.readAsBytes(), mime, f.name);
  }

  void _remove(int i) {
    setState(() => _error = null);
    widget.onChanged([...widget.pages]..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    final on = widget.enabled;
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: pages.isEmpty ? WrapAlignment.center : WrapAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: on ? _camera : null,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(pages.isEmpty ? 'Scan a page' : 'Scan next page'),
        ),
        OutlinedButton.icon(
          onPressed: on ? _photos : null,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Add photos'),
        ),
        OutlinedButton.icon(
          onPressed: on ? _pdf : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Add PDF'),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(color: context.line),
        color: context.surface,
      ),
      child: Column(
        crossAxisAlignment: pages.isEmpty
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          if (pages.isEmpty) ...[
            Icon(
              Icons.document_scanner_outlined,
              size: 32,
              color: context.inkSoft,
            ),
            const SizedBox(height: 10),
            Text(
              'Scan ${widget.what}',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Photograph each page in order, or add a PDF. Up to $maxUploadPages pages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.inkSoft, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              '${pages.length} ${pages.length == 1 ? 'file' : 'files'}, read in this order',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < pages.length; i++)
                  _PageThumb(
                    page: pages[i],
                    number: i + 1,
                    onRemove: on ? () => _remove(i) : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          buttons,
          if (_error != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                textAlign: pages.isEmpty ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: VD.missing,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  final UploadPage page;
  final int number;
  final VoidCallback? onRemove;
  const _PageThumb({required this.page, required this.number, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final Widget face = page.isPdf
        ? Container(
            color: VD.missing.withValues(alpha: context.isDark ? 0.14 : 0.07),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: VD.missing,
                  size: 30,
                ),
                const SizedBox(height: 6),
                Text(
                  page.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.inkSoft),
                ),
              ],
            ),
          )
        : Image.memory(page.bytes, fit: BoxFit.cover);
    return Semantics(
      label: 'Page $number, ${page.name}',
      child: SizedBox(
        width: 84,
        height: 108,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.line),
                ),
                child: face,
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 2,
                top: 2,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: Tooltip(
                      message: 'Remove page $number',
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
