import '../entities/wish_event_pack.dart';

abstract interface class WishEventPackRepository {
  Future<List<WishEventPack>> loadBundledPacks();

  Future<List<WishEventPack>> refreshRemotePacks();
}
