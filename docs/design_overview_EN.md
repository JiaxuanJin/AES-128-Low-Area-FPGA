# AES-128 Group Technical Reference Manual v2.0

# This document is the final detailed design specification for a highly area-optimized AES-128 encryption core. The design has been deeply optimized specifically for low-area FPGAs (such as Xilinx Artix-7/Spartan-7) and area-constrained ASIC implementations.

---

## 1. Core Architecture

### 1.1 Block Diagram

```ascii
                                     +-------------------+
                                     |   Master FSM      |
                                     |   (Controller)    |
                                     +-------------------+
                                              |
      [Plaintext]                             v  (Start/Done/State)
     -----------------------------------------------------------------
          |                                   |
          v                                   v
    +-----------+    (128-bit Reg)      +-----------+
    | State Reg | <-------------------- | Multiplexer| <---+
    +-----------+                       +-----------+      |
          |                                   ^            |
          | (128-bit)                         |            |
          v                                   |            |
    +------------------------------------------------------+-----+
    |                   AES Round Logic                          |
    |                                                            |
    |  +-----------+     +------------+     +--------------+     |
    |  | SubBytes  | --> | ShiftRows  | --> | MixColumns   |     |
    |  | (16 cyc)  |     | (0 Logic)  |     | (17 cyc)     |     |
    |  +-----------+     +------------+     +--------------+     |
    +------------------------------------------------------------+
          |                   ^
          | (AddRoundKey)     | (RoundKey)
          v                   |
    +-----------+       +------------+
    | XOR Logic | <---- | Key Expand |
    +-----------+       |(On-the-fly)|
          |             +------------+
          v
      [Ciphertext]
```

### 1.2 (Key Decisions)

| Design Dimension | Conventional Parallel Scheme        | **Proposed Design Scheme** | Advantage                |
| :---             | :---                                | :---                       | :---                     |
| **S-Box**        | 16 Look-Up Tables                   | **1 BRAM Lookup Table**    | Saves ~3200 LUTs         |
| **MixColumns**   | 4 Parallel Multiplier Arrays        | **1 Serialized Multiplier**| Saves ~800 LUTs          |
| **KeyExpansion** | Precompute and Store All Round Keys | **On-the-fly Computation** | Saves ~1400 Registers    |
| **ShiftRows**    | Shift Registers / Multiplexing      | **Hardwired**              | Zero Resource Consumption|

------------------------------------------------------------------------------------------------------------------
## 1.3 Source Code Directory

*   **Core Modules**
    *   `aes.v`: **Top-level module**Integrates key expansion, encryption/decryption logic, and FSM control.
    *   `aes_defines.vh`: **Header file**Defines global constants, FSM state codes, and configuration parameters.

*   **Key Expansion**   **by Jiaxuan Jin**
    *   `key_expand.v`: Implements the AES key expansion algorithm, generating the round keys required for each round.

*   **Round Transformations** 
    *   `sub_bytes.v`: S-Box substitution layer (SubBytes) and its inverse transformation. **by Alsulami Rami Owitq A**
    *   `shift_rows.v`: Row shifting layer (ShiftRows) and its inverse transformation. **by Qiu Haihan**
    *   `mix_columns.v`: Column mixing layer (MixColumns) and its inverse transformation. **by Liu Jingyuan**
    *   `add_round_key.v`: Round key addition layer (AddRoundKey). **by Lyu Zhengjunyi**

*   **Auxiliary Computation Modules**
    *   `mix_column_unit.v`: Submodule of`mix_columns` handling the mixing logic of a single column.
    *   `gmul_gf256.v`: GF(2^8) field multiplier used for column mixing.
    *   `gmul2_xtime.v`: Optimized  `xtime` operation (multiplication by 2), used for more efficient GF multiplication.

*   **ROMs/RAMs**
    *   `sbox_data.mem`: AES S-Box data.
    *   `inv_sbox_data.mem`: AES inverse S-Box data.
    *   `rcon_data.mem`: Round constant (Rcon) data used for key expansion.
    *   `mc_coeff_data.mem`: Column mixing coefficient data.


## 2. Module Descriptions

### 2.1 Top-Level Interface: `aes.v`  **by Liu Jingyuan**

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock, triggered on rising edge |
| `rst_n` | Input | 1 | Asynchronous reset, active low |
| `start` | Input | 1 | Start signal, valid on rising edge. Must remain low during encryption until `done` is asserted. |
| `plaintext` | Input | 128 | Plaintext input data (big-endian)|
| `key` | Input | 128 | Key input data (big-endian)|
| `ciphertext` | Output | 128 | Ciphertext output data. Valid only when `done=1`.|
| `done` | Output | 1 | Completion flag. Asserted high when encryption finishes; remains asserted until next`start`.|

### 2.2 Subbyte (`sub_bytes.v`) **by Alsulami Rami Owitq A**
*   **Function**: AES nonlinear transformation layer.
*   **Resources**: 1 XPM_MEMORY_SPROM (256x8 bit).
*   **Timing**:
    *   **Latency**: BRAM BRAM read latency of 1 cycle.
    *   **Throughput**: 1 byte/clock cycle.
    *   **Pipeline**: Implements an "address-data" pipeline, address issued at cycle N, data received at cycle N+1, state register written back at cycle N+2.
*   **State Machine**:
    *   `IDLE`: Wait for start.
    *   `CALC`: Loop 16 times (Count 0-15), processing one byte per iteration.
    *   `DONE`: Assert completion signal.

### 2.3 mix columns part (`mix_columns.v` & `mix_column_unit.v`)  **by Liu Jingyuan**
*   **Function**: AES linear transformation layer, providing diffusion.
*   **Architecture**: 
    *   `mix_columns.v` (Wrapper): Controls the loop of 4 column operations.
    *   `mix_column_unit.v` (Core): Computes the mixing of a single column.
*   **Core Operator**: GF(2^8) multiplier `gmul_gf256`.
*   **Coefficient Storage:**: Coefficient matrix `{02, 03, 01, 01}` and its cyclically shifted versions stored in 
    **BRAM** (`mc_coeff_data.mem`).
*   **Timing Alignment Technique**: 
    *   Coefficient BRAM address generated using combinational logic (`assign coeff_addr = ...`)
    *   Source data (`state`bytes) using**combinational logic**.
    *   **Effect**: BRAM output `dout` and source data `data_in` arrive at the multiplier input in the same clock cycle, eliminating the misalignment caused by a 1-cycle delay.

### 2.4 Key Expansion (`key_expand.v`)  **by Jiaxuan Jin**
*   **Function**: Generate the 128-bit round key for each round.
*   **mplementation**: 
    *   Only the current round key is stored.
    *   Contains a small state machine (`GEN_WORD`)used to compute `RotWord` -> `SubWord` -> `Rcon XOR`.
    *   Reuses S-Box logic (current version uses independent BRAM for simplified control; can be merged further).
*   **Rcon Table**: Stored in `rcon_data.mem` ROM .

---

## 3. Memory Maps

### 3.1 S-Box ROM (`sbox_data.mem`) 
Standard AES S-Box table, 256 Bytes.
*   Address `00`: `63`
*   Address `01`: `7c`
*   ...
*   Address `ff`: `16`

### 3.2MixColumns Coefficient ROM (`mc_coeff_data.mem`)
Coefficient matrix for single column computation, 16 coefficients total (expanded 4x4 matrix).
*   Address `00`: `02` (Row 0, Col 0)
*   Address `01`: `03` (Row 0, Col 1)
*   Address `02`: `01` (Row 0, Col 2)
*   Address `03`: `01` (Row 0, Col 3)
*   ...
*   Address `15`: `02` (Row 3, Col 3)

### 3.3 Round Constant ROM (`rcon_data.mem`)
Stores 10 round constants only.
*   Address `01`: `01` (Round 1)
*   Address `02`: `02` (Round 2)
*   Address `03`: `04` (Round 3)
*   ...
*   Address `0a`: `36` (Round 10)

---

## 4. Timing Diagram Description

Assume system clock is 100MHz (10ns).

1.  **T=0, Reset**: Reset: `rst_n`asserted low, all state machines reset to IDLE.
2.  **T=100ns, Start**: `start` asserted high for one cycle.
    *   FSM enters `INIT_ARK`.
    *   `state` register loads `plaintext ^ key`.
3.  **T=110ns, Round 1 Begin**: `round_ctr` = 1.
4.  **T=120ns ~ 280ns, SubBytes**:
    *   `sub_bytes` module busy for 16-18 cycles.
    *   BRAM continuously reads S-Box values.
5.  **T=290ns, ShiftRows**:
    *   Combinational logic completes shifting immediately.
6.  **T=300ns ~ 980ns, MixColumns**:
    *   `mix_columns` module busy for ~68 cycles (4 cols * 17 cycles).
    *   One multiply-accumulate computed per cycle.
7.  **T=990ns, AddRoundKey**:
    *   XOR with current round key.
    *   `key_expand` module updates key synchronously.
8.  **... Loop Rounds 2-9 ...**
9.  **Round 10**: Skip MixColumns.
10. **Done**: `done` asserted high,`ciphertext` output valid.

---

## 5. Resource Utilization - Xilinx Artix-7

| Resource | Usage | Utilization | Notes |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | **642** | 3.08% | Logic core, extremely low |
| **Slice Registers** | **1187** | 2.85% | Mainly 128-bit state register and key register |
| **Block RAM** | **2.0** | 4.00% | 1 for S-Box, 1 for coefficients |
| **Bonded IOB** | **388** | 184% | **Note**: For real hardware deployment, must modify to serial interface |
| **BUFG** | **1** | 3.13% | Global clock buffer |

### 5.1 Power Estimation
Due to extremely low logic switching activity and small resource utilization, static power dominates.
*   **Total On-Chip Power**: **~0.076 W** (76mW)
*   **Dynamic Power**: ~0.005 W
*   **Static Power**: ~0.071 W

---

## 6. Conclusion

This design successfully implements an**extremely small-area**AES-128 core.
**Through:**
1.  **Replacing logic with BRAM**Eliminating a large amount of combinational logic.
2.  **Serialized computation**Reducing parallelism from 128-bit to 8-bit.
3.  **Precise timing control**Resolving data alignment issues caused by BRAM latency.

It ultimately achieves full AES encryption functionality with extremely low resource utilization, fully compliant with the FIPS-197 standard.
