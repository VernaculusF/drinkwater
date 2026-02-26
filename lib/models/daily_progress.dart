class DailyProgress {
  final String date; // YYYY-MM-DD
  final int drank;
  final int goal;

  const DailyProgress({
    required this.date,
    required this.drank,
    required this.goal,
  });

  bool get completed => goal > 0 && drank >= goal;

  DateTime get dateTime => DateTime.parse(date);

  Map<String, dynamic> toJson() {
    return {
      'drank': drank,
      'goal': goal,
    };
  }

  static DailyProgress fromJson(String date, Map<String, dynamic> json) {
    final drankValue = json['drank'];
    final goalValue = json['goal'];
    return DailyProgress(
      date: date,
      drank: drankValue is int ? drankValue : int.tryParse('$drankValue') ?? 0,
      goal: goalValue is int ? goalValue : int.tryParse('$goalValue') ?? 0,
    );
  }
}
