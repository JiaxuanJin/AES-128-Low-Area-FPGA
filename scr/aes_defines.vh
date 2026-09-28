// ----------------------------------------------------------------------
// AES State Global Definitions
// Focus: Column-major mapping for 128-bit state
// Usage: `AES_S00(state_signal) => state_signal[0 +: 8]
// ----------------------------------------------------------------------

`ifndef AES_DEFINES_VH
`define AES_DEFINES_VH

// Byte Mapping (Column-major)
// Col 0
`define AES_S00(v) v[0   +: 8]
`define AES_S10(v) v[8   +: 8]
`define AES_S20(v) v[16  +: 8]
`define AES_S30(v) v[24  +: 8]
// Col 1
`define AES_S01(v) v[32  +: 8]
`define AES_S11(v) v[40  +: 8]
`define AES_S21(v) v[48  +: 8]
`define AES_S31(v) v[56  +: 8]
// Col 2
`define AES_S02(v) v[64  +: 8]
`define AES_S12(v) v[72  +: 8]
`define AES_S22(v) v[80  +: 8]
`define AES_S32(v) v[88  +: 8]
// Col 3
`define AES_S03(v) v[96  +: 8]
`define AES_S13(v) v[104 +: 8]
`define AES_S23(v) v[112 +: 8]
`define AES_S33(v) v[120 +: 8]

// Column Mapping
`define AES_COL0(v) v[0   +: 32]
`define AES_COL1(v) v[32  +: 32]
`define AES_COL2(v) v[64  +: 32]
`define AES_COL3(v) v[96  +: 32]

`endif // AES_DEFINES_VH
