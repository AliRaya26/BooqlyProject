/// A gap in the user's calendar with no scheduled events.
class FreeTimeSlot {
  const FreeTimeSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);
}
