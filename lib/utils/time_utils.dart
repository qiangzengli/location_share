import 'package:intl/intl.dart';

String relativeTimeZh(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.isNegative) return '刚刚';
  if (diff.inSeconds < 45) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return DateFormat('M月d日 HH:mm').format(time);
}
