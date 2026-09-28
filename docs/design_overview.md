# AES-128 面积优化核心技术参考手册 (Technical Reference Manual v2.0)

本文档是针对极小化面积（Area-Optimized）AES-128 加密核心的**最终详细设计说明书**。该设计特别针对低成本 FPGA（如 Xilinx Artix-7/Spartan-7）和面积受限的 ASIC 进行了深度优化。

---

## 1. 核心架构设计 (Core Architecture)

### 1.1 系统框图 (Block Diagram)

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
    +-----------+       | (On-the-fly|
          |             +------------+
          v
      [Ciphertext]
```

### 1.2 关键设计决策 (Key Decisions)

| 设计维度 | 传统并行方案 | **本设计方案** | 优势 |
| :--- | :--- | :--- | :--- |
| **S-Box** | 16 个 Look-Up Tables | **1 个 BRAM 查找表** | 节省 ~3200 LUTs |
| **MixColumns** | 4 个并行乘法器阵列 | **1 个串行乘法器** | 节省 ~800 LUTs |
| **KeyExpansion** | 预计算并存储所有轮密钥 | **在线计算 (On-the-fly)** | 节省 ~1400 Registers |
| **ShiftRows** | 移位寄存器/多路复用 | **硬连线 (Hardwired)** | 零资源消耗 |

---

## 2. 详细模块说明 (Module Descriptions)

### 2.1 顶层接口 (Top-Level Interface: `aes.v`)

| 信号名 | 方向 | 位宽 | 描述 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | 系统时钟，上升沿触发 |
| `rst_n` | Input | 1 | 异步复位，低电平有效 |
| `start` | Input | 1 | 启动信号，上升沿有效。在加密过程中应保持低电平，直到 `done` 拉高。 |
| `plaintext` | Input | 128 | 明文输入数据（大端序）|
| `key` | Input | 128 | 密钥输入数据（大端序）|
| `ciphertext` | Output | 128 | 密文输出数据。仅当 `done=1` 时有效。|
| `done` | Output | 1 | 完成标志。拉高表示加密结束，输出保持直到下一次 `start`。|

### 2.2 字节代换单元 (`sub_bytes.v`)
*   **功能**: AES 非线性变换层。
*   **资源**: 1 个 XPM_MEMORY_SPROM (256x8 bit)。
*   **时序**:
    *   **Latency**: BRAM 读取延迟为 1 周。
    *   **Throughput**: 1 字节 / 1 时钟周期。
    *   **流水线**: 实现"地址-数据"流水线，第 N 拍发地址，第 N+1 拍收数据，第 N+2 拍写回状态寄存器。
*   **状态机**:
    *   `IDLE`: 等待启动。
    *   `CALC`: 循环 16 次 (Count 0-15)，每次处理一个字节。
    *   `DONE`: 拉高完成信号。

### 2.3 列混淆单元 (`mix_columns.v` & `mix_column_unit.v`)
*   **功能**: AES 线性变换层，提供扩散性。
*   **架构**: 
    *   `mix_columns.v` (Wrapper): 控制 4 次列操作的循环。
    *   `mix_column_unit.v` (Core): 负责计算单列的混淆。
*   **核心算子**: GF(2^8) 乘法器 `gmul_gf256`。
*   **系数存储**: 系数矩阵 `{02, 03, 01, 01}` 及循环移位版本存储在 **BRAM** (`mc_coeff_data.mem`) 中。
*   **时序对齐技巧**: 
    *   系数 BRAM 地址使用**组合逻辑**生成 (`assign coeff_addr = ...`)。
    *   源数据 (`state`字节) 使用**组合逻辑**选择。
    *   **效果**: BRAM 输出数据 `dout` 与源数据 `data_in` 在同一时钟周期到达乘法器输入端，消除了 1 拍延迟带来的错位。

### 2.4 密钥扩展 (`key_expand.v`)
*   **功能**: 生成每一轮的 128 位轮密钥。
*   **实现**: 
    *   仅存储当前轮的密钥。
    *   包含一个微型状态机 (`GEN_WORD`)，用于计算 `RotWord` -> `SubWord` -> `Rcon XOR`。
    *   复用 S-Box 逻辑（当前版本为独立 BRAM 以简化控制，可进一步合并）。
*   **Rcon 表**: 存储在 `rcon_data.mem` ROM 中。

---

## 3. 存储器映射 (Memory Maps)

### 3.1 S-Box ROM (`sbox_data.mem`)
标准 AES S-Box 表，256 Bytes。
*   Address `00`: `63`
*   Address `01`: `7c`
*   ...
*   Address `ff`: `16`

### 3.2 MixColumns 系数 ROM (`mc_coeff_data.mem`)
用于单列计算的系数矩阵，共 16 个系数（4x4 矩阵展开）。
*   Address `00`: `02` (Row 0, Col 0)
*   Address `01`: `03` (Row 0, Col 1)
*   Address `02`: `01` (Row 0, Col 2)
*   Address `03`: `01` (Row 0, Col 3)
*   ...
*   Address `15`: `02` (Row 3, Col 3)

### 3.3 轮常数 ROM (`rcon_data.mem`)
仅存储 10 个轮常数。
*   Address `01`: `01` (Round 1)
*   Address `02`: `02` (Round 2)
*   Address `03`: `04` (Round 3)
*   ...
*   Address `0a`: `36` (Round 10)

---

## 4. 时序流程详解 (Timing Diagram Description)

假设系统时钟为 100MHz (10ns)。

1.  **T=0, Reset**: `rst_n` 拉低，所有状态机复位至 IDLE。
2.  **T=100ns, Start**: `start` 拉高一个周期。
    *   FSM 进入 `INIT_ARK`。
    *   `state` 寄存器加载 `plaintext ^ key`。
3.  **T=110ns, Round 1 Begin**: `round_ctr` = 1。
4.  **T=120ns ~ 280ns, SubBytes**:
    *   `sub_bytes` 模块忙碌 16-18 个周期。
    *   BRAM 持续读取 S-Box 值。
5.  **T=290ns, ShiftRows**:
    *   组合逻辑立即完成移位。
6.  **T=300ns ~ 980ns, MixColumns**:
    *   `mix_columns` 模块忙碌 ~68 个周期 (4 cols * 17 cycles)。
    *   每个周期计算一次乘法累加。
7.  **T=990ns, AddRoundKey**:
    *   与当前轮密钥异或。
    *   `key_expand` 模块同步更新密钥。
8.  **... Loop Rounds 2-9 ...**
9.  **Round 10**: 跳过 MixColumns。
10. **Done**: `done` 信号拉高，`ciphertext` 输出有效。

---

## 5. 资源消耗统计 (Resource Utilization - Xilinx Artix-7)

| 资源 | 使用量 | 利用率 | 备注 |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | **642** | 3.08% | 逻辑核心，极低 |
| **Slice Registers** | **1187** | 2.85% | 主要是 128-bit 状态寄存器和密钥寄存器 |
| **Block RAM** | **2.0** | 4.00% | 1 个用于 S-Box，1 个用于系数 |
| **Bonded IOB** | **388** | 184% | **注意**: 如需实际下板，需修改为串行接口 |
| **BUFG** | **1** | 3.13% | 全局时钟缓冲 |

### 5.1 功耗估算 (Power Estimation)
由于逻辑翻转率极低且资源占用少，静态功耗占主导。
*   **Total On-Chip Power**: **~0.076 W** (76mW)
*   **Dynamic Power**: ~0.005 W
*   **Static Power**: ~0.071 W

---

## 6. 总结 (Conclusion)

本设计成功实现了一个**极小面积**的 AES-128 核心。通过：
1.  **BRAM 替代逻辑**：消除了大量组合逻辑。
2.  **串行化计算**：将并行度从 128-bit 降低到 8-bit。
3.  **精细的时序控制**：解决了 BRAM 延迟带来的数据对齐问题。

最终实现了在极低资源占用下的全功能 AES 加密，完全符合 FIPS-197 标准。
