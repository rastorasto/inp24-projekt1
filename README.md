# INP — Brainfuck CPU (VHDL)

An 8-bit Brainfuck interpreter implemented as a CPU in VHDL.

- FSM datapath (program counter, memory pointer, temp register)
- `zadani/src/cpu.vhd` — the core; `zadani/login.b` — sample program
- Simulation with GHDL + cocotb, optional PYNQ synthesis

## Test

```bash
cd zadani/test && make      # needs ghdl + cocotb
```

Coursework for *Návrh počítačových systémů (INP)* at FIT VUT Brno, 2024.
