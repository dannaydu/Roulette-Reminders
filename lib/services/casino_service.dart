import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class CasinoProfile {
  const CasinoProfile({
    this.balance = 0,
    this.pendingSpins = 0,
    this.spinsEarned = 0,
    this.lifetimeWinnings = 0,
    this.lastPayout = 0,
    this.updatedAt,
  });

  static const empty = CasinoProfile();

  final int balance;
  final int pendingSpins;
  final int spinsEarned;
  final int lifetimeWinnings;
  final int lastPayout;
  final DateTime? updatedAt;

  factory CasinoProfile.fromData(Map<String, dynamic>? data) {
    int readInt(String key) {
      return (data?[key] as num?)?.toInt() ?? 0;
    }

    final updatedAt = data?['updatedAt'];

    return CasinoProfile(
      balance: readInt('balance'),
      pendingSpins: readInt('pendingSpins'),
      spinsEarned: readInt('spinsEarned'),
      lifetimeWinnings: readInt('lifetimeWinnings'),
      lastPayout: readInt('lastPayout'),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  CasinoProfile copyWith({
    int? balance,
    int? pendingSpins,
    int? spinsEarned,
    int? lifetimeWinnings,
    int? lastPayout,
    Object? updatedAt = _sentinel,
  }) {
    return CasinoProfile(
      balance: balance ?? this.balance,
      pendingSpins: pendingSpins ?? this.pendingSpins,
      spinsEarned: spinsEarned ?? this.spinsEarned,
      lifetimeWinnings: lifetimeWinnings ?? this.lifetimeWinnings,
      lastPayout: lastPayout ?? this.lastPayout,
      updatedAt: updatedAt == _sentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'balance': balance,
      'pendingSpins': pendingSpins,
      'spinsEarned': spinsEarned,
      'lifetimeWinnings': lifetimeWinnings,
      'lastPayout': lastPayout,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}

class RouletteReward {
  const RouletteReward({
    required this.id,
    required this.label,
    required this.payout,
    required this.weight,
  });

  final String id;
  final String label;
  final int payout;
  final int weight;
}

class RouletteSpinResult {
  const RouletteSpinResult({
    required this.reward,
    required this.segmentIndex,
    required this.profile,
  });

  final RouletteReward reward;
  final int segmentIndex;
  final CasinoProfile profile;
}

enum CasinoTableBetColor {
  red,
  black,
  green,
}

class ChipBetResult {
  const ChipBetResult({
    required this.amount,
    required this.choice,
    required this.didWin,
    required this.payout,
    required this.roll,
    required this.profile,
  });

  final int amount;
  final CasinoTableBetColor choice;
  final bool didWin;
  final int payout;
  final int roll;
  final CasinoProfile profile;
}

class CasinoService {
  CasinoService._();

  static final CasinoService instance = CasinoService._();

  final CollectionReference<Map<String, dynamic>> _profilesRef =
      FirebaseFirestore.instance.collection('casinoProfiles');
  final Random _random = Random();

  static const List<int> bossBetOptions = [10, 25, 50, 100];
  static const List<int> tableBetOptions = [10, 25, 50, 100, 250];
  static const Set<int> _redRolls = {1, 3, 5, 7, 9, 12, 14};
  static const Set<int> _blackRolls = {2, 4, 6, 8, 10, 11, 13};

  static const List<RouletteReward> _wheel = [
    RouletteReward(id: 'stack10', label: '10', payout: 10, weight: 18),
    RouletteReward(id: 'stack15', label: '15', payout: 15, weight: 16),
    RouletteReward(id: 'stack20', label: '20', payout: 20, weight: 14),
    RouletteReward(id: 'stack30', label: '30', payout: 30, weight: 10),
    RouletteReward(id: 'stack40', label: '40', payout: 40, weight: 7),
    RouletteReward(id: 'stack60', label: '60', payout: 60, weight: 5),
    RouletteReward(id: 'stack90', label: '90', payout: 90, weight: 3),
    RouletteReward(id: 'jackpot150', label: '150', payout: 150, weight: 1),
  ];

  List<RouletteReward> get wheel => _wheel;

  DocumentReference<Map<String, dynamic>> profileRef(String userId) {
    return _profilesRef.doc(userId);
  }

  Stream<CasinoProfile> profileStream(String userId) {
    return profileRef(userId).snapshots().map(
      (snapshot) => CasinoProfile.fromData(snapshot.data()),
    );
  }

  Future<ChipBetResult> placeTableBet({
    required String userId,
    required int amount,
    required CasinoTableBetColor choice,
  }) async {
    if (userId.isEmpty) {
      throw StateError('You must be signed in to place a bet.');
    }
    if (amount < 1) {
      throw StateError('Choose a valid chip amount.');
    }

    final profileDoc = profileRef(userId);
    final now = DateTime.now();
    final roll = _random.nextInt(15);
    final didWin = switch (choice) {
      CasinoTableBetColor.red => _redRolls.contains(roll),
      CasinoTableBetColor.black => _blackRolls.contains(roll),
      CasinoTableBetColor.green => roll == 0,
    };
    final payoutMultiplier = choice == CasinoTableBetColor.green ? 14 : 2;
    final payout = didWin ? amount * payoutMultiplier : 0;
    CasinoProfile? updatedProfile;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(profileDoc);
      final currentProfile = CasinoProfile.fromData(snapshot.data());

      if (currentProfile.balance < amount) {
        throw StateError('Not enough House Chips for that bet.');
      }

      updatedProfile = currentProfile.copyWith(
        balance: currentProfile.balance - amount + payout,
        lifetimeWinnings: currentProfile.lifetimeWinnings + payout,
        lastPayout: didWin ? payout : 0,
        updatedAt: now,
      );

      transaction.set(
        profileDoc,
        updatedProfile!.toMap(),
        SetOptions(merge: true),
      );
    });

    return ChipBetResult(
      amount: amount,
      choice: choice,
      didWin: didWin,
      payout: payout,
      roll: roll,
      profile: updatedProfile ?? CasinoProfile.empty,
    );
  }

  Future<RouletteSpinResult> spin({required String userId}) async {
    final reward = _pickReward();
    final profileDoc = profileRef(userId);
    final now = DateTime.now();
    CasinoProfile? updatedProfile;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(profileDoc);
      final currentProfile = CasinoProfile.fromData(snapshot.data());

      if (currentProfile.pendingSpins < 1) {
        throw StateError('No spins ready. Complete another task first.');
      }

      updatedProfile = currentProfile.copyWith(
        balance: currentProfile.balance + reward.payout,
        pendingSpins: currentProfile.pendingSpins - 1,
        lifetimeWinnings: currentProfile.lifetimeWinnings + reward.payout,
        lastPayout: reward.payout,
        updatedAt: now,
      );

      transaction.set(
        profileDoc,
        updatedProfile!.toMap(),
        SetOptions(merge: true),
      );
    });

    return RouletteSpinResult(
      reward: reward,
      segmentIndex: _wheel.indexWhere((segment) => segment.id == reward.id),
      profile: updatedProfile ?? CasinoProfile.empty,
    );
  }

  RouletteReward _pickReward() {
    final totalWeight = _wheel.fold<int>(
      0,
      (total, reward) => total + reward.weight,
    );
    var roll = _random.nextInt(totalWeight);

    for (final reward in _wheel) {
      roll -= reward.weight;
      if (roll < 0) {
        return reward;
      }
    }

    return _wheel.first;
  }
}

const _sentinel = Object();
