import 'package:flutter/material.dart';

/// In-app acknowledgement for AMap SDK privacy flags ([AMapPrivacyStatement]).
Future<bool> showAmapPrivacyDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('地图与定位服务说明'),
        content: const SingleChildScrollView(
          child: Text(
            '本应用使用高德地图 SDK 与高德定位 SDK 展示地图并获取位置。'
            '使用前应确保你的隐私政策已包含高德相应说明，且已向用户展示并取得同意。\n\n'
            '详情请参阅高德开放平台隐私合规说明。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('不同意'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意并继续'),
          ),
        ],
      );
    },
  );
  return accepted ?? false;
}
