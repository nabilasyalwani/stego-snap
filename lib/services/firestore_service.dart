import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stego_snap/services/notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? lastStegoServerPath;
  static String? lastSnapId;
  static String? lastSnapTitle;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _notify({required String title, required String body}) async {
    await NotificationService.createNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
    );
  }

  Future<String> createSnap({
    required String title,
    required String localImagePath,
    required String imageSource,
    String? stegoServerPath,
    String? stegoFileName,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapsRef = _db.collection('snaps').doc();
    final userRef = _db.collection('users').doc(user.uid);

    await snapsRef.set({
      'snapsId': snapsRef.id,
      'userId': user.uid,
      'userRef': userRef,
      'title': title.trim(),
      'localImagePath': localImagePath,
      'imageSource': imageSource,
      if (stegoServerPath != null) 'stegoServerPath': stegoServerPath,
      if (stegoFileName != null) 'stegoFileName': stegoFileName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (stegoServerPath != null) {
      lastStegoServerPath = stegoServerPath;
    }

    lastSnapId = snapsRef.id;
    lastSnapTitle = title.trim();

    await userRef.set({
      'lastSnapAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notify(
      title: 'Snap Saved',
      body: 'Snap saved to collection snaps with id: ${snapsRef.id}',
    );

    return snapsRef.id;
  }

  Future<void> renameSnapById({
    required String snapId,
    required String newTitle,
  }) async {
    if (snapId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    await _db.collection('snaps').doc(snapId).update({
      'title': newTitle.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    lastSnapTitle = newTitle.trim();
  }

  Future<void> shareSnapToUserId({
    required String snapId,
    required String userId,
  }) async {
    if (snapId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    final targetUserId = userId.trim();
    if (targetUserId.isEmpty) {
      throw Exception('User id is required');
    }

    final sender = _currentUser;
    if (sender == null) {
      throw Exception('User not logged in');
    }

    if (targetUserId == sender.uid) {
      throw Exception('Cannot share snap to yourself');
    }

    final snapDoc = await _db.collection('snaps').doc(snapId).get();
    if (!snapDoc.exists) {
      throw Exception('Snap not found');
    }

    final snapData = snapDoc.data() ?? <String, dynamic>{};
    final senderDoc = await _db.collection('users').doc(sender.uid).get();
    final senderData = senderDoc.data() ?? <String, dynamic>{};

    final senderName =
        (senderData['displayName'] ??
                sender.displayName ??
                sender.email ??
                'User')
            .toString();
    final senderProfileImage = (senderData['profileImage'] ?? '').toString();

    final notificationRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('shareNotifications')
        .doc();

    await _db.collection('snaps').doc(snapId).update({
      'sharedToUserIds': FieldValue.arrayUnion([targetUserId]),
      'lastSharedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await notificationRef.set({
      'notificationId': notificationRef.id,
      'type': 'share',
      'status': 'pending',
      'snapId': snapId,
      'fromUserId': sender.uid,
      'fromUserName': senderName,
      'fromUserProfileImage': senderProfileImage,
      'snapTitle': (snapData['title'] ?? 'Untitled').toString(),
      'stegoServerPath': (snapData['stegoServerPath'] ?? '').toString(),
      'stegoFileName': (snapData['stegoFileName'] ?? '').toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingShareNotifications() {
    final user = _currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('shareNotifications')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> declineShareNotification(String notificationId) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('shareNotifications')
        .doc(notificationId)
        .update({
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
          'disabledAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> acceptShareNotification(String notificationId) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final notificationRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('shareNotifications')
        .doc(notificationId);

    final notificationDoc = await notificationRef.get();
    if (!notificationDoc.exists) {
      throw Exception('Notification not found');
    }

    final notificationData = notificationDoc.data() ?? <String, dynamic>{};
    final sourceSnapId = (notificationData['snapId'] ?? '').toString();
    if (sourceSnapId.isEmpty) {
      throw Exception('Source snap id is missing');
    }

    final sourceSnapDoc = await _db.collection('snaps').doc(sourceSnapId).get();
    if (!sourceSnapDoc.exists) {
      throw Exception('Source snap not found');
    }

    final sourceData = sourceSnapDoc.data() ?? <String, dynamic>{};
    final newSnapRef = _db.collection('snaps').doc();
    final userRef = _db.collection('users').doc(user.uid);

    await newSnapRef.set({
      'snapsId': newSnapRef.id,
      'userId': user.uid,
      'userRef': userRef,
      'title':
          (sourceData['title'] ??
                  notificationData['snapTitle'] ??
                  'Shared snap')
              .toString(),
      'localImagePath': (sourceData['localImagePath'] ?? '').toString(),
      'imageSource': 'shared',
      'stegoServerPath':
          (sourceData['stegoServerPath'] ??
                  notificationData['stegoServerPath'] ??
                  '')
              .toString(),
      'stegoFileName':
          (sourceData['stegoFileName'] ??
                  notificationData['stegoFileName'] ??
                  '')
              .toString(),
      'sharedFromUserId': (notificationData['fromUserId'] ?? '').toString(),
      'sourceSnapId': sourceSnapId,
      'isSharedReceived': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await notificationRef.update({
      'status': 'accepted',
      'acceptedSnapId': newSnapRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllSnap() {
    final user = _currentUser;

    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _db
        .collection('snaps')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getLatestSnapForCurrentUser() async {
    final user = _currentUser;
    if (user == null) {
      return null;
    }

    final query = await _db
        .collection('snaps')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    return {...doc.data(), 'id': doc.id};
  }

  Future<void> deleteSnap(String snapsId) async {
    if (snapsId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    await _db.collection('snaps').doc(snapsId).delete();
  }

  Future<void> updateSnap(
    String snapsId,
    Map<String, dynamic> updatedData,
  ) async {
    if (snapsId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    await _db.collection('snaps').doc(snapsId).update({
      ...updatedData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
