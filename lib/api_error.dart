class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}
