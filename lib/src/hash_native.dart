/// The FNV-1a offset basis.
// This file is conditionally excluded from JavaScript builds.
// ignore: avoid_js_rounded_ints
const initialHash = 0xcbf29ce484222325;

/// Adds [byte] to a native FNV-1a hash.
int nextHash(int hash, int byte) => (hash ^ byte) * 0x100000001b3;
