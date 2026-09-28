# AES-128 Low-Area FPGA Implementation

A compact **AES-128 hardware implementation in Verilog HDL** targeting Xilinx Artix-7 FPGA devices.  
The project focuses on reducing hardware resource usage through **serialized datapaths, on-the-fly key expansion, lookup-table/ROM based transformations, and FSM-controlled round processing**.

> **Language:** [English](README.md) | [中文](README_CN.md)

---

## Overview

This repository contains the RTL design, testbenches, verification scripts, and design documentation for a low-area AES-128 encryption/decryption implementation developed as part of an FPGA design project.

The design implements the main AES transformations:

- **SubBytes**
- **ShiftRows**
- **MixColumns**
- **AddRoundKey**
- **AES-128 Key Expansion**

Rather than maximizing throughput with fully parallel hardware, this implementation prioritizes **resource efficiency** and demonstrates the trade-off between **area and latency** in FPGA cryptographic accelerators.

---

## Key Features

- AES-128 hardware implementation in **Verilog HDL**
- Encryption/decryption-oriented modular architecture
- **On-the-fly round-key generation**
- Serialized/iterative processing to reduce hardware cost
- GF(2^8) arithmetic for MixColumns
- Memory-based lookup data for AES transformations
- Modular Verilog testbenches for unit and system verification
- Python reference/verification script
- Synthesized and evaluated using **Xilinx Vivado 2019.2**
- Target device: **Xilinx Artix-7 XC7A100T-CSG324-1**

---

## Architecture

A simplified data flow is shown below:

```text
                 +----------------------+
                 |      Master FSM      |
                 |   Round Controller   |
                 +----------+-----------+
                            |
                            v
+------------+       +-------------+       +-------------+
| Plaintext  | ----> | State Reg   | ----> |  SubBytes   |
+------------+       +-------------+       +-------------+
                                              |
                                              v
                                        +-------------+
                                        | ShiftRows   |
                                        +-------------+
                                              |
                                              v
                                        +-------------+
                                        | MixColumns  |
                                        +-------------+
                                              |
                                              v
                                        +-------------+
                                        | AddRoundKey |
                                        +-------------+
                                              ^
                                              |
                                      +---------------+
                                      | Key Expansion |
                                      |  On-the-fly   |
                                      +---------------+
                                              ^
                                              |
                                           128-bit Key
```

The controller sequences each AES round and coordinates the transformation modules and round-key generation.

---

## Low-Area Design Strategy

The main design objective is to reduce FPGA resource usage rather than instantiate a fully parallel AES datapath.

| Design Area | Low-Area Approach | Benefit |
|---|---|---|
| SubBytes | Reuse lookup resources rather than 16 fully parallel S-Boxes | Lower logic usage |
| MixColumns | Reuse arithmetic units across data/columns | Reduced multiplier/XOR hardware |
| Key Expansion | Generate round keys on demand | Avoid storing all round keys |
| ShiftRows | Wiring/permutation-based implementation | Minimal logic cost |
| Control | FSM-driven iterative processing | Smaller datapath at the cost of latency |

This architecture is useful for studying the classic **area–performance trade-off** in FPGA cryptographic hardware.

---

## My Contribution

My main responsibilities in the group project included:

- Design and implementation of the **AES-128 Key Expansion** module
- Round-key generation using `RotWord`, `SubWord`, `Rcon`, and XOR operations
- Integration support between key expansion and AES round processing
- Development/use of a **Python AES reference implementation** for verification
- Integration and debugging across AES transformation modules
- FPGA simulation and design validation in Vivado

The project was completed collaboratively; other AES datapath modules were contributed by other team members.

---

## Repository Structure

```text
AES-128-Low-Area-FPGA/
├── src/
│   ├── aes.v
│   ├── aes_defines.vh
│   ├── add_round_key.v
│   ├── key_expand.v
│   ├── sub_bytes.v
│   ├── shift_rows.v
│   ├── mix_columns.v
│   ├── mix_column_unit.v
│   ├── gmul_gf256.v
│   ├── gmul2_xtime.v
│   ├── sbox_data.mem
│   ├── rcon_data.mem
│   └── mc_coeff_data.mem
│
├── tb/
│   ├── tb_aes.v
│   ├── tb_key_expand.v
│   ├── tb_add_round_key.v
│   ├── tb_gmul_gf256.v
│   ├── tb_mix_columns.v
│   ├── tb_shift_rows.v
│   └── tb_sub_bytes.v
│
├── python/
│   └── verify_aes.py
│
├── docs/
│   ├── design_overview_EN.md
│   └── design_overview_CN.md
│
├── README.md
└── README_CN.md
```

---

## Main RTL Modules

### `aes.v`
Top-level AES module. It coordinates the AES state, round processing, control FSM, and interaction with the key-expansion logic.

### `key_expand.v`
Generates AES-128 round keys from the original 128-bit cipher key.

The module implements the key schedule operations:

```text
RotWord -> SubWord -> Rcon XOR -> Word XOR chain
```

Only the required round-key state is maintained, supporting a more area-efficient implementation.

### `sub_bytes.v`
Implements the nonlinear AES byte-substitution transformation using S-Box lookup data.

### `shift_rows.v`
Implements the AES row permutation. This transformation can largely be expressed as rewiring/reordering and therefore requires little additional logic.

### `mix_columns.v`
Implements column diffusion over **GF(2^8)**.

### `gmul_gf256.v`
Implements finite-field multiplication used by MixColumns.

### `add_round_key.v`
XORs the current AES state with the current 128-bit round key.

---

## Verification

Verification is performed at multiple levels.

### Verilog Testbenches

Individual modules are tested using dedicated testbenches in `tb/`, including:

- Key expansion
- SubBytes
- ShiftRows
- MixColumns
- AddRoundKey
- GF(2^8) multiplication
- Full AES datapath

### Python Reference

`python/verify_aes.py` provides a software-side reference/checking workflow to compare expected AES results against the hardware implementation.

This makes debugging easier by separating:

```text
Expected AES result
        vs.
RTL simulation result
```

---

## FPGA Synthesis Result

A saved Vivado synthesis report for the `aes_core` design targets:

**Xilinx Artix-7 XC7A100T-CSG324-1**

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 915 | 63,400 | 1.44% |
| Slice Registers | 1,640 | 126,800 | 1.29% |
| Block RAM Tiles | 5 | 135 | 3.70% |
| DSPs | 0 | 240 | 0.00% |

> These figures are taken from a saved **Vivado 2019.2 synthesized design report**. Resource usage can vary between project versions and synthesis settings.

The design uses **no DSP blocks**, which is consistent with its logic/lookup-based AES arithmetic implementation.

---

## Area vs. Performance

The project intentionally explores a low-area architecture.

Earlier project iterations used different levels of serialization and therefore produced different latency/throughput trade-offs. A more serialized architecture requires fewer parallel hardware resources, but increases the number of clock cycles required per 128-bit AES block.

This is a deliberate engineering trade-off:

```text
More parallelism  -> higher throughput -> larger hardware area
More serialization -> lower area       -> higher latency
```

---

## Development Environment

- **HDL:** Verilog
- **FPGA Tool:** Xilinx Vivado 2019.2
- **Simulation:** Vivado Simulator (XSim)
- **Target FPGA:** Artix-7 XC7A100T-CSG324-1
- **Reference/Verification:** Python

---

## Getting Started

### 1. Clone the repository

```bash
git clone <your-repository-url>
cd AES-128-Low-Area-FPGA
```

### 2. Create or open a Vivado project

Add the RTL files under:

```text
src/
```

and the required memory initialization files:

```text
*.mem
```

### 3. Add simulation sources

Add the required testbench from:

```text
tb/
```

For system-level verification, use:

```text
tb/tb_aes.v
```

### 4. Run behavioral simulation

Use Vivado XSim to verify the generated ciphertext/output against the expected AES result.

### 5. Optional Python verification

Run:

```bash
python python/verify_aes.py
```

to perform software-side checking/reference verification.

---

## What This Project Demonstrates

This project demonstrates practical experience with:

- RTL design in Verilog
- FPGA-oriented architecture design
- AES-128 algorithm implementation
- Finite-field arithmetic
- FSM design
- Memory/lookup-table based optimization
- Resource-aware hardware design
- Testbench development
- Hardware/software cross-verification
- Vivado synthesis and simulation
- Debugging multi-module digital systems

---

## Notes

This repository is a cleaned version of the original Vivado development project.  
Generated Vivado folders such as `.Xil/`, cache files, simulation output, and run directories are intentionally excluded from version control.

---

## License / Academic Use

This repository is provided for portfolio, educational, and technical demonstration purposes.

If you reuse any part of the implementation in academic work, please follow your institution's academic-integrity requirements and provide appropriate attribution where required.
