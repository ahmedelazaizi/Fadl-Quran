/// Keeps the reader's audio focus separate from its touch-selected ayah.
class ReaderAudioFocus {
  String? _ayahKey;
  int _revision = 0;

  String? get ayahKey => _ayahKey;
  int get revision => _revision;

  String? highlightedKey(String? selectedKey) => _ayahKey ?? selectedKey;

  bool update({required String? ayahKey, required bool sourceActive}) {
    final nextKey = sourceActive ? ayahKey : null;
    if (nextKey == _ayahKey) return false;
    _ayahKey = nextKey;
    _revision++;
    return true;
  }

  bool isCurrent(int revision) => revision == _revision && _ayahKey != null;
}
