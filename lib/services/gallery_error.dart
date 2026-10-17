/// A save failure with an actionable message suitable for the photo screen.
class PhotoSaveException implements Exception {
  const PhotoSaveException(this.message);
  final String message;
}
