sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success({required this.value});
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure({required this.message});
  final String message;
}
