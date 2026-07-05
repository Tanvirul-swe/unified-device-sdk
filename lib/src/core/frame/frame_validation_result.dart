import 'device_frame.dart';

/// Represents the result of validating a device frame.
class FrameValidationResult {
  /// Whether the frame is valid.
  final bool isValid;

  /// The validated frame, if valid.
  final DeviceFrame? frame;

  /// Error message if the frame is invalid.
  final String? errorMessage;

  /// Error code if the frame is invalid.
  final int? errorCode;

  const FrameValidationResult._({
    required this.isValid,
    this.frame,
    this.errorMessage,
    this.errorCode,
  });

  /// Creates a successful validation result.
  factory FrameValidationResult.success(DeviceFrame frame) {
    return FrameValidationResult._(
      isValid: true,
      frame: frame,
    );
  }

  /// Creates a failed validation result.
  factory FrameValidationResult.failure(String message, {int? errorCode}) {
    return FrameValidationResult._(
      isValid: false,
      errorMessage: message,
      errorCode: errorCode,
    );
  }

  @override
  String toString() {
    if (isValid) {
      return 'FrameValidationResult.valid($frame)';
    }
    return 'FrameValidationResult.invalid($errorMessage)';
  }
}