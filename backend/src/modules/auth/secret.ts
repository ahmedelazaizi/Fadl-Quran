import { createHash, randomBytes } from 'node:crypto';

/** A random device secret; only its SHA-256 hash is stored. */
export function newDeviceSecret(): { token: string; hash: string } {
  const token = randomBytes(32).toString('base64url');
  return { token, hash: sha256(token) };
}

export function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
