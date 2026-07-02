class ObjectBoxException implements Exception {
  final String message;

  ObjectBoxException([
    this.message = 'Notes app is already open in another instance.',
  ]);

  @override
  String toString() => message;
}
