/// The initial web-safe hash value.
const initialHash = 0;

/// Adds [byte] to a hash without exceeding JavaScript's safe integer range.
int nextHash(int hash, int byte) => (hash * 31 + byte) % 281474976710597;
