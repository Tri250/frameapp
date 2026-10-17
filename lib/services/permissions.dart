import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'privacy.dart';

enum PermissionPurpose { camera, savePhoto }

typedef PermissionExplanation =
    Future<bool> Function(PermissionPurpose purpose);

abstract class PermissionBackend {
  Future<bool> hasCamera();
  Future<bool> cameraBlocked();
  Future<bool> requestCamera();
  Future<bool> hasPhotoAccess();
  Future<bool> requestPhotoAccess();
  Future<bool> openSettings();
}

class DevicePermissions implements PermissionBackend {
  @override
  Future<bool> hasCamera() => Permission.camera.isGranted;
  @override
  Future<bool> cameraBlocked() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied || status.isRestricted;
  }

  @override
  Future<bool> requestCamera() async =>
      (await Permission.camera.request()).isGranted;
  @override
  Future<bool> hasPhotoAccess() => Gal.hasAccess();
  @override
  Future<bool> requestPhotoAccess() => Gal.requestAccess();
  @override
  Future<bool> openSettings() => openAppSettings();
}

class AppPermissions {
  AppPermissions(this.consent, {PermissionBackend? backend})
    : backend = backend ?? DevicePermissions();
  final PrivacyConsent consent;
  final PermissionBackend backend;
  bool _requesting = false;

  Future<bool> ensureCamera({
    required PermissionExplanation explain,
    bool explicit = false,
  }) => _ensure(PermissionPurpose.camera, explain, explicit);

  Future<bool> ensurePhotoSave({
    required PermissionExplanation explain,
    bool explicit = false,
  }) => _ensure(PermissionPurpose.savePhoto, explain, explicit);

  Future<bool> _ensure(
    PermissionPurpose purpose,
    PermissionExplanation explain,
    bool explicit,
  ) async {
    if (!consent.accepted || _requesting) return false;
    if (kIsWeb) return true;
    _requesting = true;
    try {
      final camera = purpose == PermissionPurpose.camera;
      if (await (camera ? backend.hasCamera() : backend.hasPhotoAccess())) {
        return consent.accepted;
      }
      if (camera && await backend.cameraBlocked()) return false;
      final key = camera ? 'camera' : 'savePhoto';
      if (!explicit && await consent.store.wasPrompted(key)) return false;
      // Mark both cancellation and rejection, avoiding repeated prompts at launch.
      await consent.store.markPrompted(key);
      if (!consent.accepted || !await explain(purpose) || !consent.accepted) {
        return false;
      }
      final granted = await (camera
          ? backend.requestCamera()
          : backend.requestPhotoAccess());
      return granted && consent.accepted;
    } finally {
      _requesting = false;
    }
  }
}
