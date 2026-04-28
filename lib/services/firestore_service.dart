import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stego_snap/services/notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    required String stegoImageUrl,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final stegoFilesRef = _db.collection('stego_files').doc();
    final userRef = _db.collection('users').doc(user.uid);

    await stegoFilesRef.set({
      'ownerId': user.uid,
      'userId': user.uid,
      'ownerRef': userRef,
      'title': title.trim(),
      'stegoImageUrl': stegoImageUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notify(
      title: 'Snap Saved',
      body: 'Snap saved to collection stegoFiles with id: ${stegoFilesRef.id}',
    );

    return stegoFilesRef.id;
  }

  Future<void> renameSnapById({
    required String stegoFileId,
    required String newTitle,
  }) async {
    if (stegoFileId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    final docRef = _db.collection('stego_files').doc(stegoFileId);

    await docRef.update({
      'title': newTitle.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> shareSnapToUserId({
    required String stegoFileId,
    required String toUserId,
  }) async {
    if (stegoFileId.trim().isEmpty) {
      throw Exception('Stego file id is required');
    }

    final targetUserId = toUserId.trim();
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

    final snapDoc = await _db.collection('stego_files').doc(stegoFileId).get();
    if (!snapDoc.exists) {
      throw Exception('Snap not found');
    }

    final snapData = snapDoc.data() ?? <String, dynamic>{};

    final sharedFilesRef = _db.collection('shared_files').doc();

    await sharedFilesRef.set({
      'toUserID': targetUserId,
      'fromUserId': sender.uid,
      'stegoFileId': stegoFileId,
      'stegoTitle': snapData['title'],
      'stegoImageUrl': snapData['stegoImage'] ?? snapData['stegoImageUrl'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getCurrentUserStegoId() async {
    final user = _currentUser;
    if (user == null) {
      return null;
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    return (userData?['idStegoSnap'] ?? '').toString().trim();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingShareFiles(
    String recipientStegoId,
  ) {
    final normalizedRecipientStegoId = recipientStegoId.trim();
    if (normalizedRecipientStegoId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _db
        .collection('shared_files')
        .where('toUserID', isEqualTo: normalizedRecipientStegoId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> declineSharedFiles(String shareFileId) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _db.collection('shared_files').doc(shareFileId).update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
      'disabledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptShareFiles(String shareFileId) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final sharedFilesRef = _db.collection('shared_files').doc(shareFileId);

    final shareFileDoc = await sharedFilesRef.get();
    if (!shareFileDoc.exists) {
      throw Exception('Share file not found');
    }

    final shareData = shareFileDoc.data() ?? <String, dynamic>{};
    final stegoFileId = (shareData['stegoFileId'] ?? '').toString();
    if (stegoFileId.isEmpty) {
      throw Exception('Stego file id is missing');
    }

    final stegoFileRef = _db.collection('stego_files').doc(stegoFileId);
    final stegoFileDoc = await stegoFileRef.get();
    if (!stegoFileDoc.exists) {
      throw Exception('Stego file not found');
    }

    await sharedFilesRef.update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> loadShareNotificationData(
    Map<String, dynamic> notification,
  ) async {
    final senderId = (notification['fromUserId'] ?? '').toString();
    final stegoFileId = (notification['stegoFileId'] ?? '').toString();

    final senderDoc = senderId.isEmpty
        ? null
        : await _db.collection('users').doc(senderId).get();
    final stegoDoc = stegoFileId.isEmpty
        ? null
        : await _db.collection('stego_files').doc(stegoFileId).get();

    final senderData = senderDoc?.data() ?? <String, dynamic>{};
    final stegoData = stegoDoc?.data() ?? <String, dynamic>{};

    final senderName = (senderData['displayName'] ?? senderId).toString();

    return {
      ...notification,
      'senderName': senderName.isNotEmpty ? senderName : 'Unknown User',
      'senderProfileImage': senderData['profileImage'] ?? '',
      'stegoImage': stegoData['stegoImage'] ?? '',
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllSnap() {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _db
        .collection('stego_files')
        .where('ownerId', isEqualTo: currentUserId)
        .snapshots();
  }

  Future<void> updateShareStatus(String shareFileId, String status) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _db.collection('shared_files').doc(shareFileId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'declined') 'disabledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getLatestSnapForCurrentUser() async {
    final user = _currentUser;
    if (user == null) {
      return null;
    }

    final query = await _db.collection('stego_files').get();

    for (final doc in query.docs) {
      final data = doc.data();
      final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString();
      if (ownerId == user.uid) {
        return {...data, 'id': doc.id};
      }
    }

    return null;
  }

  Future<void> deleteSnap(String stegoFilesId) async {
    if (stegoFilesId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    final docRef = _db.collection('stego_files').doc(stegoFilesId);
    await docRef.delete();
  }

  Future<void> updateSnap(
    String stegoFilesId,
    Map<String, dynamic> updatedData,
  ) async {
    if (stegoFilesId.trim().isEmpty) {
      throw Exception('Snap id is required');
    }

    await _db.collection('stego_files').doc(stegoFilesId).update({
      ...updatedData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
