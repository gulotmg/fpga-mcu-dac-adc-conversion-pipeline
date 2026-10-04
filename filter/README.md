# filter/ : 4th-Order Active Sallen-Key Low-Pass Filter & Discrete Linear Power Supply

Custom 2-layer hardware PCB engineered to replace the baseline passive RC filter with a 4th-order unity-gain Sallen-Key active low-pass filter ($f_0 \approx 79.58\text{ kHz}$, $-80\text{ dB/decade}$ roll-off) powered by an isolated discrete linear series pass regulator.

Designed in KiCad 10.0.6, simulated in LTspice.

> **Quick Links**: [Bill of Materials (BOM_filter.csv)](BOM_filter.csv) | [KiCad Schematic](pcb/filter.kicad_sch) | [KiCad PCB Layout](pcb/filter.kicad_pcb) | [LTspice Simulation](simulation/filter.asc)

---

## Discrete Power Supply Design & Analysis

While using an off-the-shelf monolithic LDO (such as an LM317, L7805, or LP2985) would have been more straightforward, designing a custom discrete series pass regulator was deliberately chosen for educational satisfaction since calculating thermal drift compensation, differential error tracking, Miller stability compensation, and foldback current limiting has been more interesting and rewarding. PSRR drops above $10\text{ kHz}$ (falling below $30\text{ dB}$ at $100\text{ kHz}\dots 1\text{ MHz}$) (this is also the reason why datasheets suggest to put a 100 nF capacitor close to the power supply). Since the power supply used (5V from the Nucleo) may generate high-frequency spikes precisely where op-amp PSRR is weakest, a quiet power supply definitely helps keeping supply noise from degrading dynamic spectral measurements of interest.

#### Sizing, Dimensioning & Thermal Compensation Analysis

The discrete regulator topology was sized and analyzed according to classical analog power supply design principles:

### A. Bandgap Reference Voltage ($\mathbf{V_{ref}}$ Derivation & Thermal Compensation)

#### 1. Biasing & Core Topology
Red LED $\mathbf{D_1}$ is used as the reference diode in order to drive a constant current generator (PNP transistor $\mathbf{Q_7}$ biased by $\mathbf{R_1 = 330\,\Omega}$, $\mathbf{R_2 = 330\,\Omega}$, $\mathbf{R_3 = 1.0\text{ k}\Omega}$, and bypass capacitor $\mathbf{C_1 = 47\,\mu\text{F}}$) that feeds the reference core. Forward-biased GaAsP red LEDs exhibit a negative forward voltage temperature coefficient ($\mathbf{\approx -2.0\text{ mV/}^\circ\text{C}}$), providing complementary thermal tracking.

The reference core consists of transistors $\mathbf{Q_1, Q_2, Q_3}$ and resistors $\mathbf{R_5 = 1.0\text{ k}\Omega}$, $\mathbf{R_6 = 10.0\text{ k}\Omega}$, $\mathbf{R_7 = 470\,\Omega}$:
- **Diode-connected $\mathbf{Q_2}$**: carries current $\mathbf{I_1}$ through collector resistor $\mathbf{R_5}$;
- **Degenerated $\mathbf{Q_1}$**: carries current $\mathbf{I_2}$ through collector resistor $\mathbf{R_6}$, with emitter degeneration resistor $\mathbf{R_7}$;
- **Feedback $\mathbf{Q_3}$**: base driven by the collector of $\mathbf{Q_1}$, emitter grounded, and collector tied to node $\mathbf{V_{ref}}$.

#### 2. Analytical Derivation
Neglecting base currents ($\mathbf{I_2 \approx I_{C(Q1)} \approx I_{E(Q1)}}$), the difference in base-emitter voltages appears directly across emitter degeneration resistor $\mathbf{R_7}$:

$$\mathbf{V_{BE(Q2)} - V_{BE(Q1)} = I_{E(Q1)} R_7 \cong I_2 R_7}$$

Using the fundamental BJT exponential relationship $\mathbf{I_C = I_S e^{V_{BE}/V_T} \implies V_{BE} = V_T \ln(I_C / I_S)}$, with thermal voltage $\mathbf{V_T = \frac{kT}{q} \approx 25.86\text{ mV}}$ (at $\mathbf{T = 300\text{ K}}$):

$$\mathbf{V_{BE(Q2)} - V_{BE(Q1)} = \frac{kT}{q} \left[ \ln\left(\frac{I_{C(Q2)}}{I_S}\right) - \ln\left(\frac{I_{C(Q1)}}{I_S}\right) \right] = \frac{kT}{q} \ln\left(\frac{I_1}{I_2}\right) = I_2 R_7}$$

Because $\mathbf{V_{BE(Q2)} \approx V_{BE(Q3)}}$, the voltage drops across the two collector load resistors balance ($\mathbf{I_1 R_5 \approx I_2 R_6 \implies \frac{I_1}{I_2} \approx \frac{R_6}{R_5}}$). Solving for the Proportional To Absolute Temperature (PTAT) current $\mathbf{I_2}$:

$$\mathbf{I_2 = \frac{1}{R_7} \frac{kT}{q} \ln\left(\frac{R_6}{R_5}\right)}$$

The reference voltage at node $\mathbf{V_{ref}}$ is taken at the collector of feedback transistor $\mathbf{Q_3}$:

$$\mathbf{V_{ref} = I_2 R_6 + V_{BE(Q3)} = V_{BE(Q3)} + \frac{R_6}{R_7} \frac{kT}{q} \ln\left(\frac{R_6}{R_5}\right)}$$

#### 3. Numerical Evaluation
Substituting circuit component values ($\mathbf{R_5 = 1.0\text{ k}\Omega}$, $\mathbf{R_6 = 10.0\text{ k}\Omega}$, $\mathbf{R_7 = 470\,\Omega}$, $\mathbf{V_T \approx 25.86\text{ mV}}$, and $\mathbf{V_{BE(Q3)} \approx 0.65\text{ V}}$):

$$\mathbf{\frac{R_6}{R_5} = \frac{10\text{ k}\Omega}{1.0\text{ k}\Omega} = 10 \implies \ln(10) \approx 2.303, \qquad \frac{R_6}{R_7} = \frac{10\,000\,\Omega}{470\,\Omega} \approx 21.28}$$

$$\mathbf{V_{ref} \approx 0.65\text{ V} + 21.28 \times 25.86\text{ mV} \times 2.303 \approx 0.65\text{ V} + 1.267\text{ V} \approx 1.92\text{ V}}$$

#### 4. Thermal Drift Compensation
The temperature variation of the reference voltage is expressed as:

$$\mathbf{\Delta V_{ref} = \Delta V_{BE(Q3)} + \frac{R_6}{R_7} \frac{k\,\Delta T}{q} \ln\left(\frac{R_6}{R_5}\right)}$$

The negative temperature coefficient of $\mathbf{V_{BE(Q3)}}$ ($\mathbf{\approx -2.2\text{ mV/}^\circ\text{C}}$) is compensated by the positive temperature coefficient of the PTAT voltage term, minimizing thermal drift across temperature.

Since the circuit includes foldback short-circuit protection but no overvoltage clamp (for design simplicity), it is strongly recommended not to exceed $\mathbf{+10\text{ V}}$ DC supply to protect the components.



### B. Closed-Loop Output Voltage Scaling

The feedback divider formed by $\mathbf{R_{10} = 1.0\text{ k}\Omega}$ and $\mathbf{R_{11} = 2.0\text{ k}\Omega}$ compares the output voltage against the error amplifier base-emitter junction and reference voltage ($\mathbf{V_{BE(Q5)} + V_{ref}}$):

$$\mathbf{V_{\text{feedback}} = V_O \cdot \frac{R_{11}}{R_{10} + R_{11}} = V_O \cdot \frac{2.0\text{ k}\Omega}{1.0\text{ k}\Omega + 2.0\text{ k}\Omega} = \frac{2}{3} V_O \equiv V_{BE(Q5)} + V_{ref}}$$

$$\mathbf{V_{O,\text{ideal}} = (V_{BE(Q5)} + V_{ref}) \cdot \left( 1 + \frac{R_{10}}{R_{11}} \right) = 1.5 \cdot (V_{BE(Q5)} + V_{ref})}$$

Using $\mathbf{V_{ref} \approx 1.92\text{ V}}$ calculated above and nominal $\mathbf{V_{BE(Q5)} \approx 0.65\text{ V}}$:

$$\mathbf{V_{O,\text{ideal}} = 1.5 \cdot (0.65\text{ V} + 1.92\text{ V}) = 1.5 \cdot 2.57\text{ V} \approx 3.86\text{ V}}$$



### C. Loop Stability & Miller Compensation

To guarantee unconditional stability under reactive loads, capacitor $\mathbf{C_5 = 1.0\text{ nF}}$ is placed across the collector-base junction of pass driver $\mathbf{Q_5}$. Via the Miller effect, the equivalent capacitance seen at the driver base is multiplied by the stage voltage gain:

$$\mathbf{C_{\text{Miller}} = C_5 \cdot (1 + |A_v|)}$$

This creates a dominant low-frequency pole, rolling off loop gain well before parasitic phase shifts from the series pass transistor $\mathbf{Q_4}$ and output decoupling capacitors can degrade phase margin, ensuring a stable power supply and preventing potential oscillations.


### D. Foldback Current Limiting

Resistor $\mathbf{R_{sense} = 10\,\Omega}$ senses the load current $\mathbf{I_L}$ delivered by series pass transistor $\mathbf{Q_4}$. A resistive divider formed by $\mathbf{R_{F1} = R_{14} = 220\,\Omega}$ and $\mathbf{R_{F2} = R_{15} = 1.0\text{ k}\Omega}$ biases sense transistor $\mathbf{Q_6}$ (2N2222), whose emitter is tied to $\mathbf{V_O}$:

$$\mathbf{V_{BE, Q6} = (V_O + I_L R_{sense}) \frac{R_{F2}}{R_{F1} + R_{F2}} - V_O}$$

Imposing $\mathbf{V_{BE, Q6} = 0.6\text{ V}}$ at the activation threshold gives:

$$\mathbf{0.6\text{ V} = (V_O + I_{th} R_{sense}) \frac{R_{F2}}{R_{F1} + R_{F2}} - V_O}$$

Solving for the threshold current $\mathbf{I_{th}}$:

$$\mathbf{I_{th} = \frac{0.6\text{ V}}{R_{sense}} \left( 1 + \frac{R_{F1}}{R_{F2}} \right) + \frac{V_O}{R_{sense}} \left( \frac{R_{F1}}{R_{F2}} \right)}$$

Under dead short-circuit conditions ($\mathbf{V_O = 0\text{ V}}$), the output current folds back to:

$$\mathbf{I_{sc} = \frac{0.6\text{ V}}{R_{sense}} \left( 1 + \frac{R_{F1}}{R_{F2}} \right) = \frac{0.6\text{ V}}{10\,\Omega} \left( 1 + \frac{220\,\Omega}{1000\,\Omega} \right) = 73.2\text{ mA}}$$

Substituting $\mathbf{V_{O,\text{ideal}} \approx 3.86\text{ V}}$ obtained from the bandgap reference and closed-loop scaling equations, the current threshold before regulation drop is:

$$\mathbf{I_{th} = 73.2\text{ mA} + \frac{3.86\text{ V}}{10\,\Omega} \left( \frac{220\,\Omega}{1000\,\Omega} \right) = 73.2\text{ mA} + 84.9\text{ mA} \approx 158.1\text{ mA}}$$

When load current exceeds $\mathbf{I_{th}}$, $\mathbf{Q_6}$ conducts and shunts base drive current away from driver $\mathbf{Q_5}$ and series pass $\mathbf{Q_4}$, folding back the output current from $\mathbf{I_{th} \approx 158.1\text{ mA}}$ down to $\mathbf{I_{sc} \approx 73.2\text{ mA}}$. This limits the maximum short-circuit power dissipation to:

$$\mathbf{P_{diss,\max} = V_{IN} \cdot I_{sc} = 5.0\text{ V} \times 73.2\text{ mA} \approx 366\text{ mW}}$$

protecting the series pass transistor from thermal runaway.
