# VHDL/ — FPGA DDS Waveform Generator (Xilinx Spartan-7, SEA board)

Fully custom VHDL DDS that reads 256×8-bit waveform lookup tables from Block
RAM and streams samples to a TI DAC7311 over a 3-wire serial interface, while
outputting a 100 kHz trigger for the STM32 ADC (EXTI11). Vendor IP is used
only for the three BRAM ROMs; everything else is custom, synthesizable VHDL.

```
            ┌────────────────────────────────────────────┐
 CLK 100MHz │  addr_reg (phase accumulator)               │
 RESET ───► │      │ addr_mask (step = 1,2,4…128)         │
 SELECT1 ──►│      ▼                                      │
 (freq ×2)  │  ROM_Sin / ROM_trig / ROM_saw (BRAM, 256×8) │
 SELECT2 ──►│      │ wave_mode MUX                        │
 (waveform) │      ▼                                      │
            │  16-bit frame packer + serial FSM ─► DAC_DIN│
            │                              ──────► DAC_CLK│ (50 MHz)
            │                              ──────► DAC_SYNC│
            │  100 kHz divider ────────────► INT_PIN      │
            └────────────────────────────────────────────┘
```

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
| `INT_PIN` | out | 100 kHz trigger → STM32 PA11 / EXTI11 |

## Implementation

- **Waveform ROMs** — three BRAM IP cores (`ROM_Sin`, `ROM_trig`, `ROM_saw`),
  256 entries × 8 bit, initialized from MATLAB-generated `.coe` files. All
  three are read in parallel with the same address; a MUX selects the output.
- **Phase accumulator / frequency control** — `addr_reg` is incremented by the
  one-hot step `addr_mask` at the end of every serial frame. `SELECT1`
  doubles the step (1→2→…→128→1): output frequency = `f_update · step / 256`,
  i.e. ≈ 1/2/4/8 kHz; the same frequencies used in the measurement campaign.
  Step > 1 trades time resolution for frequency (amplitude resolution unchanged).
- **Waveform select** — 2-bit mode counter incremented with 'SELECT2': `00` sine, `01` triangle,
  `11` sawtooth; the unused state safely defaults to sine. 
- **DAC7311 serial interface** — 2-state FSM (`WAIT_FOR_SYNC`, `DATA_MOVING`).
  ~3.6 µs inter-frame gap with SYNC high, then SYNC low and 16 bits shifted
  MSB first: `DIN` updated while SCLK high, shifted on SCLK low (DAC latches
  on the falling edge). Frame format: `[PD1:PD0][D11:D0][X:X]` =
  `"00" & sample(8) & "000000"` (8-bit code in D11:D4, power-down bits = 00).
- **100 kHz trigger** — 1000-cycle counter: `INT_PIN` high ≈ 1 µs, low ≈ 9 µs,
  period 10 µs.
- **Reset / buttons** — ~20 ms counter-based debouncing; reset restores FSM,
  accumulator, step and counters.

## Timing summary

| Parameter | Value |
|---|---|
| System clock | 100 MHz |
| DAC serial clock | 50 MHz |
| Serial frame | 16 bits (~0.32 µs) + ~3.6 µs gap |
| DAC update rate | ≈ 255 kHz |
| Base output frequency (step = 1) | ≈ 1 kHz |
| Trigger period | 10 µs (100 kHz) |

## Build & program

1. Open `DAConSEA.xpr` in Vivado (≥ 2019.1, Spartan-7).
2. If IP was not committed regenerated: right-click BRAM IPs → *Reset Output
   Products* → *Generate Output Products*.
3. Regenerate `.coe` tables if needed (256 points, 8 bit, see `coe/`).
4. Run synthesis → implementation → generate bitstream; program the SEA board.
5. To load the bitstream to the SEA board see https://github.com/Pillar1989/spartan-edge-esp32-boot and https://www.digikey.de/en/product-highlight/s/seeed/spartan-edge-accelerator-board-resources
6. Pin assignments: see `constraints/*.xdc`.

## Design notes

- Amplitude resolution is deliberately limited to 8 bit (DAC7311 driven with 8-bit codes);
- Single-process synchronous design: one clock domain, no CDC issues, easier manageability. 
- Usage of 'signal', this allows for greater observability with respects to 'variable' for instance.
