import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../utils/logger.dart';

enum SpeechPermissionStatus {
  granted,
  denied,
  notAvailable,
}

@immutable
class SpeechPermissionResult {
  final SpeechPermissionStatus status;
  final String? message;

  const SpeechPermissionResult._(this.status, [this.message]);

  bool get isGranted => status == SpeechPermissionStatus.granted;

  static const SpeechPermissionResult granted = SpeechPermissionResult._(SpeechPermissionStatus.granted);

  static SpeechPermissionResult denied([String? message]) =>
      SpeechPermissionResult._(SpeechPermissionStatus.denied, message);

  static SpeechPermissionResult notAvailable([String? message]) =>
      SpeechPermissionResult._(SpeechPermissionStatus.notAvailable, message);
}

class SpeechService {
  final stt.SpeechToText _speechToText;
  bool _initialized = false;

  final ValueNotifier<String> transcript = ValueNotifier<String>('');
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  SpeechService({stt.SpeechToText? speechToText}) : _speechToText = speechToText ?? stt.SpeechToText();

  Future<SpeechPermissionResult> ensureInitialized() async {
    if (_initialized) {
      final hasPermission = await _speechToText.hasPermission;
      if (hasPermission) {
        return SpeechPermissionResult.granted;
      }
      return SpeechPermissionResult.denied('Speech permission not granted');
    }

    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          final message = error.errorMsg.isNotEmpty ? error.errorMsg : 'Speech recognition error';
          errorMessage.value = message;
          Logger.error('Speech error: ${error.errorMsg}', null, null, 'SpeechService');
        },
        onStatus: (status) {
          isListening.value = status == 'listening';
        },
        debugLogging: kDebugMode,
      );

      _initialized = true;

      if (!available) {
        return SpeechPermissionResult.notAvailable('Speech recognition not available on this device');
      }

      final hasPermission = await _speechToText.hasPermission;
      if (!hasPermission) {
        return SpeechPermissionResult.denied('Microphone / speech permission denied');
      }

      return SpeechPermissionResult.granted;
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize speech service', e, stackTrace, 'SpeechService');
      return SpeechPermissionResult.notAvailable('Unable to start speech recognition');
    }
  }

  Future<bool> startListening({String? localeId}) async {
    errorMessage.value = null;

    final permission = await ensureInitialized();
    if (!permission.isGranted) {
      errorMessage.value = permission.message;
      return false;
    }

    try {
      transcript.value = '';
      await _speechToText.listen(
        onResult: (result) {
          transcript.value = result.recognizedWords;
        },
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
          onDevice: true,
        ),
      );

      final started = _speechToText.isListening;
      isListening.value = started;
      return started;
    } catch (e, stackTrace) {
      Logger.error('Failed to start listening', e, stackTrace, 'SpeechService');
      errorMessage.value = 'Failed to start listening';
      isListening.value = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } catch (e, stackTrace) {
      Logger.error('Failed to stop listening', e, stackTrace, 'SpeechService');
    } finally {
      isListening.value = false;
    }
  }

  Future<void> cancel() async {
    try {
      await _speechToText.cancel();
    } catch (e, stackTrace) {
      Logger.error('Failed to cancel listening', e, stackTrace, 'SpeechService');
    } finally {
      isListening.value = false;
    }
  }

  void dispose() {
    transcript.dispose();
    isListening.dispose();
    errorMessage.dispose();
  }
}
