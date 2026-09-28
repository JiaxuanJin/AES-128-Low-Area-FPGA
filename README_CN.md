# AES-128 低面积 FPGA 硬件实现

这是一个使用 **Verilog HDL** 实现的 AES-128 FPGA 硬件项目，目标器件为 Xilinx Artix-7。  
项目重点不是追求极限吞吐率，而是通过 **串行化计算、按需密钥扩展、查找表/ROM 和 FSM 控制**，研究如何降低 AES 硬件实现的资源占用。

> **语言：** [English](README.md) | [中文](README_CN.md)

---

## 项目简介

本仓库整理了一个低面积 AES-128 FPGA 项目的 RTL 源码、Testbench、Python 验证程序以及设计文档。

设计包含 AES 的主要运算模块：

- **SubBytes（字节代换）**
- **ShiftRows（行移位）**
- **MixColumns（列混合）**
- **AddRoundKey（轮密钥加）**
- **AES-128 Key Expansion（密钥扩展）**

与一次实例化大量并行运算单元的高吞吐架构不同，本项目更强调 **硬件资源利用率**，用于展示 FPGA 密码学设计中典型的：

**面积（Area）与性能（Performance）之间的权衡。**

---

## 项目特点

- 使用 **Verilog HDL** 实现 AES-128 硬件逻辑
- 模块化 AES 数据通路
- 支持按轮生成密钥的 **On-the-fly Key Expansion**
- 通过串行/迭代计算降低硬件资源开销
- 使用 GF(2^8) 有限域运算实现 MixColumns
- 使用 `.mem` 数据文件保存 AES 查找数据
- 提供模块级与系统级 Verilog Testbench
- 提供 Python 参考/验证程序
- 使用 **Xilinx Vivado 2019.2** 开发与综合
- 目标 FPGA：**Xilinx Artix-7 XC7A100T-CSG324-1**

---

## 系统架构

简化后的数据流如下：

```text
                 +----------------------+
                 |      Master FSM      |
                 |      轮控制器         |
                 +----------+-----------+
                            |
                            v
+------------+       +-------------+       +-------------+
|  Plaintext | ----> |  State Reg  | ----> |  SubBytes   |
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
                                      |   按需生成密钥  |
                                      +---------------+
                                              ^
                                              |
                                          128-bit Key
```

Master FSM 负责控制 AES 每一轮的执行顺序，并协调数据通路与密钥扩展模块。

---

## 低面积设计思路

这个项目的核心目标是：

> 尽量减少并行硬件单元，用更多时钟周期换取更低的 FPGA 资源占用。

| 模块 | 低面积实现思路 | 主要作用 |
|---|---|---|
| SubBytes | 复用查找资源，而不是同时放置大量并行 S-Box | 减少逻辑资源 |
| MixColumns | 复用有限域运算单元 | 降低乘法/XOR 电路数量 |
| Key Expansion | 每轮按需生成 Round Key | 不需要保存全部轮密钥 |
| ShiftRows | 主要通过数据重排/连线实现 | 额外资源较少 |
| 控制部分 | FSM 控制迭代执行 | 用延迟换面积 |

因此这个项目能够很好地体现硬件设计中的经典关系：

```text
更多并行计算 -> 更高吞吐率 -> 更多硬件资源

更多串行复用 -> 更低资源占用 -> 更多计算周期
```

---

## 我的主要工作

本项目为小组合作项目，我主要负责：

- **AES-128 Key Expansion 密钥扩展模块**的设计与实现
- 实现 `RotWord`、`SubWord`、`Rcon` 与 XOR 组成的 AES Key Schedule
- 协助完成 Key Expansion 与 AES 主数据通路的集成
- 使用/开发 **Python AES 参考实现**进行结果验证
- 协助整合 SubBytes、ShiftRows、MixColumns 等模块
- Vivado 仿真、联调与问题排查

项目其他 AES 数据通路模块由小组其他成员共同完成。

---

## 仓库结构

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

## 主要 RTL 模块说明

### `aes.v`

AES 顶层模块。

主要负责：

- 保存当前 AES State
- 管理轮计数
- 控制各个 AES 运算模块
- 调用密钥扩展模块
- 通过 FSM 完成整个 AES 运算流程

---

### `key_expand.v`

AES-128 密钥扩展模块，也是我在该小组项目中主要负责的部分。

AES-128 的初始密钥长度为 128 bit，需要根据 Key Schedule 生成各轮 Round Key。

核心流程可以理解成：

```text
RotWord
   ↓
SubWord
   ↓
Rcon XOR
   ↓
与前面的 Key Word 逐级 XOR
   ↓
生成下一轮 Round Key
```

本设计采用按需更新 Round Key 的方式，而不是预先把所有轮密钥全部存储下来，从而减少寄存器开销。

---

### `sub_bytes.v`

实现 AES 的非线性字节代换。

输入 State 中的每个 Byte 都通过 AES S-Box 进行替换。

---

### `shift_rows.v`

实现 AES 的行移位操作。

ShiftRows 本质上属于数据位置重新排列，因此可以主要通过布线/索引重排完成，不需要复杂的计算单元。

---

### `mix_columns.v`

实现 AES 的列混合，用于提高数据扩散性。

其中涉及：

**GF(2^8) 有限域运算。**

---

### `gmul_gf256.v`

实现 GF(2^8) 中的有限域乘法，为 MixColumns 提供底层运算支持。

---

### `add_round_key.v`

将当前 128-bit AES State 与当前 Round Key 进行 XOR：

```text
State' = State XOR RoundKey
```

---

## 验证方法

本项目使用多层验证方式。

### Verilog Testbench

`tb/` 中分别提供了不同模块的 Testbench，例如：

- Key Expansion
- SubBytes
- ShiftRows
- MixColumns
- AddRoundKey
- GF(2^8) 乘法
- 完整 AES 数据通路

这种方法可以先单独验证每一个模块，再进行整体联调。

---

### Python 参考验证

项目中的：

```text
python/verify_aes.py
```

用于在软件侧生成/检查 AES 结果。

调试时可以将：

```text
Python 计算得到的 Expected Result

            VS

Verilog RTL 仿真得到的 Result
```

进行对比，从而帮助定位硬件实现中的问题。

---

## FPGA 综合结果

保存的 Vivado 综合报告中，`aes_core` 设计的目标器件为：

**Xilinx Artix-7 XC7A100T-CSG324-1**

综合结果：

| FPGA 资源 | 使用量 | 可用量 | 利用率 |
|---|---:|---:|---:|
| Slice LUTs | 915 | 63,400 | 1.44% |
| Slice Registers | 1,640 | 126,800 | 1.29% |
| Block RAM Tiles | 5 | 135 | 3.70% |
| DSPs | 0 | 240 | 0.00% |

> 以上数据来自项目中保存的 **Vivado 2019.2 Synthesis Report**。不同设计版本与综合设置可能产生不同的资源利用结果。

其中 DSP 使用量为 **0**，说明 AES 运算主要通过普通逻辑、查找数据和有限域运算结构实现。

---

## 面积与性能权衡

本项目在开发过程中尝试过不同程度的串行化设计。

串行程度越高：

- 同时工作的硬件单元越少
- FPGA 资源占用越低
- 但完成一个 128-bit AES Block 所需的时钟周期会增加

因此该项目主要研究：

```text
Performance
    ↑
    |        Fully Parallel AES
    |
    |
    |   Iterative Architecture
    |
    | Low-Area Serialized AES
    +----------------------------> Hardware Area
```

这也是 FPGA/ASIC 架构设计中非常重要的一类工程取舍。

---

## 开发环境

- **硬件描述语言：** Verilog HDL
- **FPGA 开发工具：** Xilinx Vivado 2019.2
- **仿真工具：** Vivado Simulator (XSim)
- **目标器件：** Artix-7 XC7A100T-CSG324-1
- **参考验证：** Python

---

## 如何运行

### 1. Clone 项目

```bash
git clone <your-repository-url>
cd AES-128-Low-Area-FPGA
```

### 2. 在 Vivado 中建立/打开工程

将：

```text
src/
```

中的 Verilog RTL 文件加入 Design Sources。

同时加入需要的：

```text
*.mem
```

数据文件。

### 3. 添加仿真文件

将：

```text
tb/
```

中的 Testbench 加入 Simulation Sources。

如果需要进行完整系统验证，可以使用：

```text
tb/tb_aes.v
```

### 4. 运行 Behavioral Simulation

使用 Vivado XSim 运行仿真，并检查输出结果是否与预期 AES Ciphertext 一致。

### 5. Python 验证

可运行：

```bash
python python/verify_aes.py
```

进行软件侧参考验证。

---

## 这个项目体现的能力

通过这个项目，我实践了：

- Verilog RTL 设计
- FPGA 数字系统设计
- AES-128 算法硬件实现
- AES Key Expansion
- GF(2^8) 有限域运算
- FSM 控制器设计
- 资源复用与低面积优化
- Verilog Testbench 编写
- Python + RTL 交叉验证
- Vivado 仿真与综合
- 多模块集成与 Debug
- 面积、延迟和吞吐率之间的工程权衡

---

## 说明

该仓库是从原始 Vivado 开发工程中整理出的 GitHub 展示版本。

以下 Vivado 自动生成内容不会上传到 GitHub：

```text
.Xil/
*.cache/
*.runs/
*.sim/
Vivado 临时文件与日志
```

这样可以保留真正有价值的 RTL、验证代码和设计文档，同时让仓库结构更清晰。

---

## License / Academic Use

本仓库主要用于个人作品集、学习和技术展示。

如果在课程作业、论文或其他学术项目中引用/复用代码，请遵循所在学校的 Academic Integrity 要求，并根据需要注明来源。
