# 🚀 Week 01 — Complete Commands & Execution Flow (Cadence Xcelium)

This document records the full reproducible flow used in Week-01.

---

## 1️⃣ Local Machine (VS Code)

After writing RTL and testbench:

```bash
git add .
git commit -m "week-01: single-cycle RV32I + testbench + waveform"
git push
```

## 2️⃣ Login to University Server
```bash
ssh sharjeel@<server_address>
cd ~/sharjeelphd/Research/riscv-microarchitecture-lab
git pull
```

## 3️⃣ Load Cadence Environment
```bash
cad
1.3  (Cadence 2025 EDA version)
which xrun
xrun -version

output 
/eda/cadence/.../xrun
TOOL: xrun(64) 24.03-s004
```
## 4️⃣ Clean Previous Simulation Data

```bash
rm -rf work xcelium.d artifacts/*
mkdir -p artifacts
chmod u+rwx artifacts
```

## 5️⃣ Compile & Elaborate RTL + Testbench

```bash
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv -l artifacts/xrun_elab.log

tail -n 200 artifacts/xrun_elab.log

```

## 6️⃣ Run Simulation
```bash
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv -R -access +rwc -l artifacts/xrun_run.log

```

## 7️⃣ View Waveform
```bash
gtkwave waves.vcd 

```