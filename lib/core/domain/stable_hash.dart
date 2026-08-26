/// A non-negative 31-bit hash of [value], stable across Dart releases.
///
/// FNV-1a rather than `String.hashCode`, which Dart explicitly does not promise
/// is stable between releases — or even between runs of the same program.
///
/// Two things here depend on that promise. A notification id has to be
/// reproducible in a test, and a provider's colour has to be the *same* colour
/// tomorrow: a list where Netflix is blue today and orange after an upgrade is a
/// list nobody can learn to scan.
int stableHash(String value) {
  int hash = 0x811C9DC5;

  for (final int unit in value.codeUnits) {
    hash ^= unit;
    // Multiply by the FNV prime, kept inside 32 bits. Dart ints are 64-bit, so
    // the mask is what makes this the specified algorithm rather than something
    // that merely resembles it.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  // Non-negative, because callers use it as an index and Android wants a
  // positive notification id.
  return hash & 0x7FFFFFFF;
}
