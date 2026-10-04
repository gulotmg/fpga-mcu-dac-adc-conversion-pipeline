# VHDL/ : FPGA DDS Waveform Generator (Xilinx Spartan-7, SEA board)

Fully custom VHDL DDS that reads 256x8-bit waveform lookup tables from synthesizable
inferred ROMs and streams samples to a TI DAC7311 over a 3-wire serial interface, while
outputting a 500 kHz trigger for the STM32 ADC (EXTI11). 

The architecture integrates a 3-wire SPI slave interface (CS, SCLK, MOSI) that allows the STM32 MCU
to reprogram the 32-bit phase increment accumulator at runtime for automated frequency sweeps.

> **Quick Links**: [VHDL Source Code (src/DAC.vhd)](DAConSEA.srcs/src/DAC.vhd) | [Timing/Pin Constraints (constraints/)](DAConSEA.srcs/constraints/constraints.xdc) | [Pre-built Bitstream (DAC.bit)](DAC.bit) | [Test Bench (tb_DAC.vhd)](DAConSEA.srcs/sim/tb_DAC.vhd)

## Ports

| Port | Dir | Description |
|---|---|---|
| `CLK` | in | 100 MHz system clock |
| `RESET` | in | Active-low, debounced (~20 ms) |
| `SELECT1` | in | Active-low button: left-shifts `addr_mask` (x2 frequency step, wraps 128->1) |
| `SELECT2` | in | Active-low button: cycles waveform mode |
| `MOSI` | in | SPI data in from STM32 PA7 |
| `SCLK` | in | SPI clock in from STM32 PA5 |
| `CS` | in | Active-low SPI frame select from STM32 PA6 |
| `DAC_DIN` | out | Serial data to DAC7311 (MSB first) |
| `DAC_CLK` | out | 50 MHz serial clock (shift-ring divider) |
| `DAC_SYNC` | out | Active-low frame sync |
| `INT_PIN` | out | 500 kHz trigger -> STM32 PA11 / EXTI11 |

## Implementation

- **Waveform ROMs** : three inferred ROM tables (`sin_data`, `trig_data`, `saw_data`),
  256 entries x 8 bit defined directly in VHDL as synthesizable arrays.
  A multiplexer selects the active waveform based on the selected mode.
- **Phase accumulator / frequency control** : 32-bit phase accumulator with fixed-point
  arithmetic (`UQ8.24`). The top 8 bits index the 256 ROM samples (integer part),
  while the lower 24 bits accumulate the decimal phase step on each frame.
  The tuning word for 1000 Hz is $M = 1\,803\,886$.
- **Runtime SPI frequency configuration** : 3-state FSM (`WAIT_FOR_SYNC`, `DATA_MOVING`, `PHASE_RECEIVE`).
  When `CS = '0'`, the FSM immediately switches to `PHASE_RECEIVE`.
  `SCLK` edges are detected by sampling through a 2-bit shift register (`SCLK_mask`) at 100 MHz.
  Each rising edge shifts `MOSI` into `phase_inc(31 downto 0)`.
  When `CS = '1'`, `phase_chosen <= phase_inc` latches the word, `phase_acc` resets to 0 for phase alignment,
  and the FSM returns to `WAIT_FOR_SYNC`.
  On system reset, `phase_inc` defaults to `phase_chosen` to preserve host-configured frequency.
- **Waveform select** : 2-bit mode counter incremented with 'SELECT2': `00` sine, `01` triangle,
  `11` sawtooth; the unused state safely defaults to sine. 
- **DAC7311 serial interface** : 16-bit shift frame at 50 MHz serial clock with inter-frame SYNC delay (in accordance to datasheet).
- **500 kHz trigger** : simply achieved by a modulo-200 counter on the 100 MHz clock.
- **Reset / buttons** : ~20 ms counter-based debouncing; reset restores FSM,
  accumulator, step and counters.

## Timing summary

| Parameter | Value |
|---|---|
| System clock | 100 MHz |
| DAC serial clock | 50 MHz |
| Serial frame | 16 bits|
| Output frequency | 1000.00 Hz (M = 1803886) and multiples |
| Trigger period | (500 kHz) |
| SPI slave bit depth | 32 bits |

## Build & program

1. Open `DAConSEA.xpr` in Vivado (>= 2019.1, Spartan-7).
2. Run synthesis -> implementation -> generate bitstream; program the SEA board.
3. To load the bitstream to the SEA board see https://github.com/Pillar1989/spartan-edge-esp32-boot and https://www.digikey.de/en/product-highlight/s/seeed/spartan-edge-accelerator-board-resources
4. Pin assignments: see `constraints/*.xdc` (CS on M14, SCLK on C4, MOSI on B13, INT_PIN on N14).

## Design notes

- Amplitude resolution is deliberately limited to 8 bit (DAC7311 driven with 8-bit codes);
- Single-process synchronous design: one clock domain, easier manageability. 
- Usage of 'signal', this allows for greater observability with respects to 'variable' for instance.
