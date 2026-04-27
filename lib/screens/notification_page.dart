import 'package:flutter/material.dart';
import 'package:stego_snap/services/firestore_service.dart';
import 'package:stego_snap/services/notification_service.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/widgets/profile.dart';
import 'package:stego_snap/widgets/custom_button.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirestoreService _firestoreService = FirestoreService();

  String _serverBaseUrl() {
    return 'http://10.0.2.2:8000';
  }

  String? _buildImageUrl(Map<String, dynamic> notification) {
    final serverPath = (notification['stegoServerPath'] as String?)?.trim();
    if (serverPath == null || serverPath.isEmpty) {
      return null;
    }
    if (serverPath.startsWith('http')) {
      return serverPath;
    }
    return '${_serverBaseUrl()}/$serverPath';
  }

  Future<void> _declineNotification(String notificationId) async {
    try {
      await _firestoreService.declineShareNotification(notificationId);
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Declined',
        body: 'Notification has been disabled.',
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Decline Failed',
        body: e.toString(),
      );
    }
  }

  Future<void> _acceptNotification(String notificationId) async {
    try {
      await _firestoreService.acceptShareNotification(notificationId);
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Share Accepted',
        body: 'Photo has been added to your database.',
      );
    } catch (e) {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Accept Failed',
        body: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: const TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 25),
            _buildSystemNotification(),
            // const SizedBox(height: 25),
            // Expanded(child: _buildShareNotificationList()),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationContainer(
    String title,
    Widget content,
    double borderRadius,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.purpleField,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildSystemNotification() {
    return _buildNotificationContainer(
      'System Notification',
      const Text(
        "Succesfully decode message!",
        style: TextStyle(
          fontSize: 14,
          fontFamily: "Poppins",
          color: Colors.white,
        ),
      ),
      50,
    );
  }

  Widget _buildShareNotificationList() {
    return StreamBuilder(
      stream: _firestoreService.getPendingShareNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load notifications: ${snapshot.error}',
            style: const TextStyle(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text(
            'No incoming share notifications.',
            style: TextStyle(color: Colors.white),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 25),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            data['notificationId'] = doc.id;
            return _buildShareNotification(data);
          },
        );
      },
    );
  }

  Widget _buildShareNotification(Map<String, dynamic> notification) {
    final senderName = (notification['fromUserName'] ?? 'Unknown User')
        .toString();
    final notificationId = (notification['notificationId'] ?? '').toString();
    final imageUrl = _buildImageUrl(notification);

    return _buildNotificationContainer(
      'Share Notification',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileWidget(
                size: 50,
                iconSize: 35,
                profileImageUrl: (notification['fromUserProfileImage'] ?? '')
                    .toString(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Send you a secret message",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: "Poppins",
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/rectangle1.png',
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      'assets/images/rectangle1.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onTap: () => _declineNotification(notificationId),
                  width: 50,
                  height: 40,
                  label: 'Decline',
                  fontSize: 14,
                  fontColor: Colors.white,
                  backgroundColor: AppColors.transparentPurpleButton,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  onTap: () => _acceptNotification(notificationId),
                  width: 50,
                  height: 40,
                  label: 'Accept',
                  fontSize: 14,
                  fontColor: AppColors.darkPurpleText,
                  gradient: const LinearGradient(
                    colors: [Colors.white, AppColors.purpleButton],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      20,
    );
  }
}
