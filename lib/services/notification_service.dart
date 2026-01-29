import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        data: json['data'] ?? {},
      );
}

class NotificationService {
  static const String _storageKey = 'app_notifications';

  static Future<void> saveNotification(String title, String body, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await getNotifications();
      
      // Check if notification with same title and body already exists in last 5 seconds
      final now = DateTime.now();
      final isDuplicate = notifications.any((n) =>
          n.title == title &&
          n.body == body &&
          now.difference(n.timestamp).inSeconds < 5);
      
      if (isDuplicate) {
        print('[Notification Service] Duplicate notification ignored');
        return;
      }
      
      final newNotification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        data: data,
      );
      
      notifications.insert(0, newNotification);
      
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      print('[Notification Service] Notification saved: $title');
    } catch (e) {
      print('[Notification Service] Error saving: $e');
    }
  }

  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr == null) return [];
      
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList.map((n) => NotificationModel.fromJson(n)).toList();
    } catch (e) {
      print('[Notification Service] Error retrieving: $e');
      return [];
    }
  }

  static Future<void> clearNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('[Notification Service] Error clearing: $e');
    }
  }
}
