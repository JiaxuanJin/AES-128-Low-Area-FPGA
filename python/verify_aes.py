#!/usr/bin/env python3
"""
AES-128 全面验证脚本 (Comprehensive Debug Script)
===================================================
目的: 排查 Verilog AES Core 解密输出错误 (e32b25ff72bdb6a5fdfac97bd82de36c)
方法: 逐步模拟 Verilog 的行为, 并对比正确的 Python 参考值, 精确定位偏差的位置.
"""

# ============================================================================
# Standard AES Tables
# ============================================================================
sbox = [
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16]

inv_sbox = [
    0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
    0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
    0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
    0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
    0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
    0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
    0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
    0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
    0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
    0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
    0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
    0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
    0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
    0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
    0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
    0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d]

rcon = [0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36]

# ============================================================================
# GF(2^8) Arithmetic
# ============================================================================
def xtime(a):
    return ((a << 1) ^ 0x1b) & 0xff if (a & 0x80) else (a << 1) & 0xff

def gmul(a, b):
    p = 0
    for _ in range(8):
        if b & 1: p ^= a
        a = xtime(a)
        b >>= 1
    return p

# ============================================================================
# AES Transformations
# ============================================================================
def sub_bytes(s, inv=False):
    return [inv_sbox[b] if inv else sbox[b] for b in s]

def shift_rows(s, inv=False):
    s = list(s)
    if not inv:
        s[1],s[5],s[9],s[13] = s[5],s[9],s[13],s[1]
        s[2],s[6],s[10],s[14] = s[10],s[14],s[2],s[6]
        s[3],s[7],s[11],s[15] = s[15],s[3],s[7],s[11]
    else:
        s[1],s[5],s[9],s[13] = s[13],s[1],s[5],s[9]
        s[2],s[6],s[10],s[14] = s[10],s[14],s[2],s[6]
        s[3],s[7],s[11],s[15] = s[7],s[11],s[15],s[3]
    return s

def mix_columns(s, inv=False):
    out = [0]*16
    for c in range(4):
        col = s[c*4:c*4+4]
        if not inv:
            out[c*4+0] = gmul(col[0],2)^gmul(col[1],3)^col[2]^col[3]
            out[c*4+1] = col[0]^gmul(col[1],2)^gmul(col[2],3)^col[3]
            out[c*4+2] = col[0]^col[1]^gmul(col[2],2)^gmul(col[3],3)
            out[c*4+3] = gmul(col[0],3)^col[1]^col[2]^gmul(col[3],2)
        else:
            out[c*4+0] = gmul(col[0],0xe)^gmul(col[1],0xb)^gmul(col[2],0xd)^gmul(col[3],0x9)
            out[c*4+1] = gmul(col[0],0x9)^gmul(col[1],0xe)^gmul(col[2],0xb)^gmul(col[3],0xd)
            out[c*4+2] = gmul(col[0],0xd)^gmul(col[1],0x9)^gmul(col[2],0xe)^gmul(col[3],0xb)
            out[c*4+3] = gmul(col[0],0xb)^gmul(col[1],0xd)^gmul(col[2],0x9)^gmul(col[3],0xe)
    return out

def add_round_key(s, k):
    return [a^b for a,b in zip(s, k)]

# ============================================================================
# Key Expansion
# ============================================================================
def key_expansion(key_bytes):
    keys = [list(key_bytes)]
    cur = list(key_bytes)
    for i in range(1, 11):
        temp = cur[12:16]
        temp = [sbox[temp[1]], sbox[temp[2]], sbox[temp[3]], sbox[temp[0]]]
        temp[0] ^= rcon[i]
        new = [0]*16
        for j in range(4): new[j] = cur[j] ^ temp[j]
        for k in range(1, 4):
            for j in range(4): new[k*4+j] = cur[k*4+j] ^ new[k*4+j-4]
        cur = new
        keys.append(list(cur))
    return keys

# ============================================================================
# Helper
# ============================================================================
def hex_s(val):
    if isinstance(val, (bytes, bytearray)):
        return "".join(f"{x:02x}" for x in val)
    return "".join(f"{x:02x}" for x in val)

# ============================================================================
# AES Encryption (Standard)
# ============================================================================
def aes_encrypt(pt, key):
    keys = key_expansion(key)
    s = add_round_key(list(pt), keys[0])
    for i in range(1, 10):
        s = sub_bytes(s)
        s = shift_rows(s)
        s = mix_columns(s)
        s = add_round_key(s, keys[i])
    s = sub_bytes(s)
    s = shift_rows(s)
    s = add_round_key(s, keys[10])
    return s

# ============================================================================
# AES Decryption - Equivalent Inverse Cipher (EIC)
# ============================================================================
def aes_decrypt_eic(ct, key, verbose=True):
    raw_keys = key_expansion(key)
    
    dec_keys = [raw_keys[10]]  # InitARK uses K10
    for k in range(9, 0, -1):
        dec_keys.append(mix_columns(raw_keys[k], inv=True))
    dec_keys.append(raw_keys[0])  # Final uses K0
    
    s = list(ct)
    s = add_round_key(s, dec_keys[0])
    if verbose: print(f"  After InitARK (^K10): {hex_s(s)}")
    
    for i in range(1, 10):
        s = sub_bytes(s, inv=True)
        s = shift_rows(s, inv=True)
        s = mix_columns(s, inv=True)
        s = add_round_key(s, dec_keys[i])
        if verbose: print(f"  After Round {i:2d}:       {hex_s(s)}")
    
    s = sub_bytes(s, inv=True)
    s = shift_rows(s, inv=True)
    s = add_round_key(s, dec_keys[10])
    if verbose: print(f"  After Final (^K0):    {hex_s(s)}")
    return s

# ============================================================================
# BUG SIMULATION: Wrong InitARK key due to round_count carryover
# ============================================================================
def aes_decrypt_eic_BUGGY(ct, key, verbose=True):
    """
    模拟 Verilog Bug:
    - 加密后 round_count 残留为 10
    - 进入 KEY_GEN 时, ke_rd_addr = inv ? (10-round_count) : round_count = 10-10 = 0
    - BRAM 读取地址 0 (K0), 由于 1 周期延迟, INIT_ARK 拿到的是 K0 而不是 K10
    - 后续轮次 round_count 正确 (1..10), ke_rd_addr 正确 (9..0)
    """
    raw_keys = key_expansion(key)
    
    # 解密用的密钥 (EIC): K9'..K1' 需要 InvMixColumns
    eic_keys = {}
    eic_keys[0] = raw_keys[0]
    eic_keys[10] = raw_keys[10]
    for k in range(1, 10):
        eic_keys[k] = mix_columns(raw_keys[k], inv=True)
    
    if verbose:
        print(f"  [BUG] InitARK 使用 K0 (地址0) 而不是 K10 (地址10)")
        print(f"        K0  = {hex_s(raw_keys[0])}")
        print(f"        K10 = {hex_s(raw_keys[10])}")
    
    s = list(ct)
    # BUG: InitARK XOR with K0 instead of K10
    s = add_round_key(s, raw_keys[0])
    if verbose: print(f"  After InitARK (^K0):  {hex_s(s)} ← WRONG!")
    
    # Rounds 1-9: use correct EIC keys (K9'..K1')
    for i in range(1, 10):
        s = sub_bytes(s, inv=True)
        s = shift_rows(s, inv=True)
        s = mix_columns(s, inv=True)
        round_key_addr = 10 - i  # addr = 10-round_count
        s = add_round_key(s, eic_keys[round_key_addr])
        if verbose: print(f"  After Round {i:2d} (^K{round_key_addr}'):{' ' if round_key_addr>=10 else ''} {hex_s(s)}")
    
    # Final round (round_count=10): addr = 10-10 = 0, uses K0
    s = sub_bytes(s, inv=True)
    s = shift_rows(s, inv=True)
    s = add_round_key(s, raw_keys[0])
    if verbose: print(f"  After Final (^K0):    {hex_s(s)}")
    return s


# ============================================================================
# Main
# ============================================================================
if __name__ == "__main__":
    key = bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
    pt  = bytes.fromhex("3243f6a8885a308d313198a2e0370734")
    ct  = bytes.fromhex("3925841d02dc09fbdc118597196a0b32")
    
    print("=" * 70)
    print("Step 1: 验证密钥扩展 (Key Expansion)")
    print("=" * 70)
    keys = key_expansion(key)
    # FIPS-197 Appendix A.1 expected round keys for key 2b7e...
    fips_k10 = "d014f9a8c9ee2589e13f0cc8b6630ca6"
    print(f"  K0:  {hex_s(keys[0])}")
    print(f"  K10: {hex_s(keys[10])}")
    print(f"  K10 (FIPS Expected): {fips_k10}")
    assert hex_s(keys[10]) == fips_k10, "Key Expansion FAILED!"
    print("  ✓ Key Expansion 正确\n")
    
    print("=" * 70)
    print("Step 2: 验证加密 (Encryption)")
    print("=" * 70)
    enc_result = aes_encrypt(pt, key)
    print(f"  Encrypted: {hex_s(enc_result)}")
    print(f"  Expected:  {hex_s(ct)}")
    assert hex_s(enc_result) == hex_s(ct), "Encryption FAILED!"
    print("  ✓ Encryption 正确\n")
    
    print("=" * 70)
    print("Step 3: 正确的 EIC 解密 (Reference)")
    print("=" * 70)
    dec_result = aes_decrypt_eic(ct, key)
    print(f"  Decrypted: {hex_s(dec_result)}")
    print(f"  Expected:  {hex_s(pt)}")
    assert hex_s(dec_result) == hex_s(pt), "Decryption FAILED!"
    print("  ✓ Decryption 正确\n")
    
    print("=" * 70)
    print("Step 4: 模拟 Verilog Bug — round_count 残留导致错误")
    print("=" * 70)
    print()
    print("  Bug 分析:")
    print("  ────────")
    print("  1. Test Case 1 (加密) 完成后, round_count = 10")
    print("  2. Test Case 2 (解密) 开始, IDLE 不重置 round_count")
    print("  3. KEY_GEN 阶段: ke_rd_addr = inv?(10-round_count) = 10-10 = 0")
    print("     → BRAM 读地址 0 (K0)")
    print("  4. ke_done 时: round_count <= 0, ke_rd_addr 变为 10-0 = 10")
    print("     → 但 BRAM 有 1 周期读延迟!")
    print("  5. INIT_ARK 时: ke_rd_key 仍为上一周期读取的 K0")
    print("     → current_state = CT ^ K0 (错误! 应为 CT ^ K10)")
    print()
    
    buggy_result = aes_decrypt_eic_BUGGY(ct, key)
    observed_verilog = "e32b25ff72bdb6a5fdfac97bd82de36c"
    
    print()
    print(f"  Buggy output: {hex_s(buggy_result)}")
    print(f"  Verilog 观察: {observed_verilog}")
    
    if hex_s(buggy_result) == observed_verilog:
        print("  ✓✓✓ Bug 复现成功! Buggy 输出与 Verilog 波形完全一致!")
        print()
        print("  ╔═══════════════════════════════════════════════════════════════╗")
        print("  ║  根因确认: round_count 未在 IDLE->KEY_GEN 转换时重置          ║")
        print("  ║  修复方案: 在 IDLE 状态的 start 分支中添加 round_count <= 0   ║")
        print("  ╚═══════════════════════════════════════════════════════════════╝")
    else:
        print("  ✗ Bug 未复现, 原因可能在其他地方")
        print(f"  差异分析: buggy={hex_s(buggy_result)}, observed={observed_verilog}")
    
    print()
    print("=" * 70)
    print("Step 5: 修复验证")
    print("=" * 70)
    print("  修复: aes_core.v 第 129-131 行")
    print("    IDLE: if (start) begin")
    print("      ke_start    <= 1'b1;")
    print("      round_count <= 4'd0;  // ← 新增: 重置 round_count")
    print("      state       <= KEY_GEN;")
    print("    end")
    print()
    print("  修复后, KEY_GEN 阶段 round_count=0:")
    print("    ke_rd_addr = inv?(10-0)=10 → BRAM 预读 K10")
    print("    ke_done 时 round_count<=0 (不变), 地址保持 10")
    print("    INIT_ARK 时 ke_rd_key = K10 ✓")
