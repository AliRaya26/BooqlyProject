class ReadingGoalModel {
  final int yearlyBookGoal; // 0 = not set
  final int dailyPageGoal;  // 0 = not set

  const ReadingGoalModel({this.yearlyBookGoal = 0, this.dailyPageGoal = 0});

  bool get hasYearlyGoal => yearlyBookGoal > 0;
  bool get hasDailyGoal => dailyPageGoal > 0;
  bool get hasAnyGoal => hasYearlyGoal || hasDailyGoal;

  factory ReadingGoalModel.fromMap(Map<String, dynamic> map) => ReadingGoalModel(
        yearlyBookGoal: (map['yearlyBookGoal'] as num?)?.toInt() ?? 0,
        dailyPageGoal: (map['dailyPageGoal'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'yearlyBookGoal': yearlyBookGoal,
        'dailyPageGoal': dailyPageGoal,
      };

  ReadingGoalModel copyWith({int? yearlyBookGoal, int? dailyPageGoal}) =>
      ReadingGoalModel(
        yearlyBookGoal: yearlyBookGoal ?? this.yearlyBookGoal,
        dailyPageGoal: dailyPageGoal ?? this.dailyPageGoal,
      );
}

class GoalProgress {
  final ReadingGoalModel goal;
  final int booksCompletedThisYear;
  final int pagesReadToday;
  final int year;

  const GoalProgress({
    required this.goal,
    required this.booksCompletedThisYear,
    required this.pagesReadToday,
    required this.year,
  });

  double get yearlyProgress => goal.yearlyBookGoal > 0
      ? (booksCompletedThisYear / goal.yearlyBookGoal).clamp(0.0, 1.0)
      : 0.0;

  double get dailyProgress => goal.dailyPageGoal > 0
      ? (pagesReadToday / goal.dailyPageGoal).clamp(0.0, 1.0)
      : 0.0;

  bool get yearlyComplete => yearlyProgress >= 1.0;
  bool get dailyComplete => dailyProgress >= 1.0;
}
