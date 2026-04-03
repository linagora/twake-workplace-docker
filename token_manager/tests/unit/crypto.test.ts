import { describe, it, expect } from 'vitest'
import { encrypt, decrypt, hashToken, generateUmbrellaToken } from '../../src/api/services/crypto.js'

const TEST_KEY = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'

describe('crypto', () => {
  describe('encrypt/decrypt', () => {
    it('roundtrips a plaintext string', () => {
      const plaintext = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test-token'
      const encrypted = encrypt(plaintext, TEST_KEY)
      const decrypted = decrypt(encrypted, TEST_KEY)
      expect(decrypted).toBe(plaintext)
    })

    it('produces different ciphertexts for the same plaintext (unique IV)', () => {
      const plaintext = 'same-token-value'
      const a = encrypt(plaintext, TEST_KEY)
      const b = encrypt(plaintext, TEST_KEY)
      expect(a).not.toBe(b)
    })

    it('throws on tampered ciphertext', () => {
      const encrypted = encrypt('secret', TEST_KEY)
      const tampered = encrypted.slice(0, -4) + 'XXXX'
      expect(() => decrypt(tampered, TEST_KEY)).toThrow()
    })

    it('throws on wrong key', () => {
      const encrypted = encrypt('secret', TEST_KEY)
      const wrongKey = 'ff'.repeat(32)
      expect(() => decrypt(encrypted, wrongKey)).toThrow()
    })
  })

  describe('hashToken', () => {
    it('produces a consistent SHA-256 hash', () => {
      const token = 'twt_abc123'
      const hash1 = hashToken(token)
      const hash2 = hashToken(token)
      expect(hash1).toBe(hash2)
      expect(hash1).toHaveLength(64)
    })

    it('produces different hashes for different tokens', () => {
      expect(hashToken('twt_aaa')).not.toBe(hashToken('twt_bbb'))
    })
  })

  describe('generateUmbrellaToken', () => {
    it('generates a token with twt_ prefix', () => {
      const token = generateUmbrellaToken()
      expect(token).toMatch(/^twt_[a-f0-9]{32,}$/)
    })

    it('generates unique tokens', () => {
      const a = generateUmbrellaToken()
      const b = generateUmbrellaToken()
      expect(a).not.toBe(b)
    })
  })
})
