/// Standardized result envelope for operations, commands, disk IO, and retro dialogs.
class OperationResult<T> {
  final bool isSuccess;
  final T? data;
  final String? message;
  final String? error;

  const OperationResult.success([this.data, this.message])
      : isSuccess = true,
        error = null;

  const OperationResult.failure(this.error, {this.message, this.data})
      : isSuccess = false;

  bool get isFailure => !isSuccess;

  /// Returns the error description if failed, or message if succeeded.
  String? get statusText => isSuccess ? message : error;

  @override
  String toString() => isSuccess
      ? 'OperationResult.success(data: $data, message: $message)'
      : 'OperationResult.failure(error: $error, message: $message)';
}
