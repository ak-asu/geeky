import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_provider.g.dart';

/// Content received from a share intent (text/URL or file attachment).
class ShareContent {
  const ShareContent({this.text, this.filePath, this.mimeType});

  /// Shared text or URL. Navigate to CreateNoteScreen when set.
  final String? text;

  /// Absolute path to a shared file or image. Navigate to UploadMediaScreen when set.
  final String? filePath;

  /// MIME type of the shared file (e.g. 'image/jpeg', 'application/pdf').
  final String? mimeType;
}

/// Holds a share intent that arrived while the user was not on the home screen
/// (e.g. cold-start share while unauthenticated, or share while deep in a sub-route).
/// HomeScreen listens to this provider and navigates once it becomes non-null.
@Riverpod(keepAlive: true)
class PendingShare extends _$PendingShare {
  @override
  ShareContent? build() => null;

  void set(ShareContent content) => state = content;
  void clear() => state = null;
}
