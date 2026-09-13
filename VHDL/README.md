# VHDL/ — FPGA DDS Waveform Generator (Xilinx Spartan-7, SEA board)

Fully custom VHDL DDS that reads 256×8-bit waveform lookup tables from synthesizable
inferred ROMs and streams samples to a TI DAC7311 over a 3-wire serial interface, while
outputting a 500 kHz trigger for the STM32 ADC (EXTI11). Fully custom, synthesizable VHDL
with no vendor IP cores or `.coe` files.

> **Quick Links**: [VHDL Source Code (src/DAC.vhd)](src/DAC.vhd) | [Timing/Pin Constraints (constraints/)](constraints/constraints.xdc) | [Pre-built Bitstream (DAC.bit)](DAC.bit)

## Ports

| Port | Dir | Description |
|---|---|---|
| `CLK` | in | 100 MHz system clock |
| `RESET` | in | Active-low, debounced (~20 ms) |
| `SELECT1` | in | Active-low button: left-shifts `addr_mask` (×2 frequency step, wraps 128→1) |
| `SELECT2` | in | Active-low button: cycles waveform mode |
| `DAC_DIN` | out | Serial data to DAC7311 (MSB first) |
| `DAC_CLK` | out | 50 MHz serial clock (shift-ring divider) |
| `DAC_SYNC` | out | Active-low frame sync |
| `INT_PIN` | out | 500 kHz trigger → STM32 PA11 / EXTI11 |

## Implementation

- **Waveform ROMs** : three inferred ROM tables (`sin_data`, `trig_data`, `saw_data`),
  256 entries × 8 bit defined directly in VHDL as synthesizable arrays.
  A multiplexer selects the active waveform based on the selected mode.
- **Phase accumulator / frequency control** : 32-bit phase accumulator with fixed-point
  arithmetic (`UQ8.24`). The top 8 bits index the 256 ROM samples (integer part),
  while the lower 24 bits accumulate the decimal phase step on each frame.
  The tuning word for 1000 Hz is $M = 1\,803\,886$.
- **Waveform select** : 2-bit mode counter incremented with 'SELECT2': `00` sine, `01` triangle,
  `11` sawtooth; the unused state safely defaults to sine. 
- **DAC7311 serial interface** : 2-state FSM (`WAIT_FOR_SYNC`, `DATA_MOVING`).
  inter-frame gap with SYNC high, then SYNC low and 16 bits shifted
  MSB first: `DIN` updated while SCLK high, shifted on SCLK low (DAC latches
  on the falling edge).
- **500 kHz trigger** : simply achieved by a counter.
- **Reset / buttons** : ~20 ms counter-based debouncing; reset restores FSM,
  accumulator, step and counters.

## Timing summary

| Parameter | Value |
|---|---|
| System clock | 100 MHz |
| DAC serial clock | 50 MHz |
| Serial frame | 16 bits|
| Output frequency | 1000.00 Hz (M = 1803886) |
| Trigger period |(500 kHz) |

## Build & program

1. Open `DAConSEA.xpr` in Vivado (≥ 2019.1, Spartan-7).
2. Run synthesis → implementation → generate bitstream; program the SEA board.
3. To load the bitstream to the SEA board see https://github.com/Pillar1989/spartan-edge-esp32-boot and https://www.digikey.de/en/product-highlight/s/seeed/spartan-edge-accelerator-board-resources
4. Pin assignments: see `constraints/*.xdc`.

## Design notes

- Amplitude resolution is deliberately limited to 8 bit (DAC7311 driven with 8-bit codes);
- Single-process synchronous design: one clock domain, easier manageability. 
- Usage of 'signal', this allows for greater observability with respects to 'variable' for instance.