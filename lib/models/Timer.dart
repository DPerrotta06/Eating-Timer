class ModelTimer {
  final int? timerId;
  final String title;
  final double duration;
  final bool isPaused;
  final double elapsedTime;

  ModelTimer({
    this.timerId,
    required this.title,
    required this.duration,
    required this.isPaused,
    required this.elapsedTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'timerId': timerId,
      'title': title,
      'duration': duration,
      'isPaused': isPaused ? 1 : 0,
      'elapsedTime': elapsedTime,
    };
  }

  factory ModelTimer.fromMap(Map<String, dynamic> map) {
    return ModelTimer(
      timerId: map['timerId'],
      title: map['title'],
      duration: (map['duration'] as num).toDouble(),
      isPaused: map['isPaused'] == 1,
      elapsedTime: (map['elapsedTime'] as num).toDouble(),
    );
  }
}
