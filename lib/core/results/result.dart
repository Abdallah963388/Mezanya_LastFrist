import '../../features/app_state/domain/failures/app_failure.dart';

class Result<T> {
  const Result._({
    required this.data,
    required this.failure,
  });

  final T? data;
  final AppFailure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;

  factory Result.success(T data) {
    return Result._(
      data: data,
      failure: null,
    );
  }

  factory Result.failure(AppFailure failure) {
    return Result._(
      data: null,
      failure: failure,
    );
  }
}
