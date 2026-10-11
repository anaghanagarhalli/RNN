
# RNN-Based Voice Stability Monitor Accelerator (PS-01) : Team 23 : Anagha & Deepthi

The Voice Stability Monitor (PS-01) is an ultra-low-power, edge-native Recurrent Neural Network (RNN) accelerator. It is custom-engineered to continuously evaluate live telephony feature streams, compute real-time stability scores, and flag degradation directly on silicon. Operating completely independent of cloud reliance, this accelerator utilizes a fixed-point Gated Recurrent Unit (GRU) architecture optimized for sub-millisecond latency and sub-milliwatt energy efficiency.

## Key Features

* **Zero-Energy Silence Bypass:** An early-stage sniffer evaluates the energy of incoming frames and instantly branches the compute engine to a bypass state if the energy falls below a configurable threshold, completely freezing multiplier activity and saving dynamic power.


* **Hardware Saturation Clamping:** Prevents catastrophic fixed-point integer wrap-arounds by safely clamping extreme accumulation results to standard 16-bit boundaries (±32767).


* **Fixed-Point GRU Architecture:** Utilizes INT8 signed weights and INT16 Q8.8 activations/states, supported by 256-entry ROM Look-Up Tables (LUTs) for Sigmoid and Tanh activations.



---

## Repository Structure & File Descriptions

Based on the project's repository and RTL-to-GDSII documentation, the files are categorized by their function in the ASIC design flow.

### RTL Source Code (Datapath & Control)

* **`voice_stability_monitor_top.sv`**: The master top-level wrapper that orchestrates the control, datapath, and clock gating logic, tying external AMBA interfaces to internal core buses.


* **`axi_stream_receiver.sv`**: Manages high-speed data ingestion using standard AXI-Stream handshaking and houses the Feature 0 Energy Sniffer for the silence bypass novelty.


* **`rnn_compute_engine.sv`**: The mathematical core containing a finite state machine (FSM) that time-multiplexes a single Multiply-Accumulate (MAC) unit across feature inputs and hidden units. It includes the hardware-level saturation arithmetic and the `SILENCE_BYPASS` state.


* **`reg_file.sv`**: Serves as the software-accessible control center via an AXI-Lite memory-mapped interface. It manages core configuration registers, mid-call flushes, stability thresholds, and novelty telemetry counters.


* **`hidden_state_mem.sv`**: An INT16 Recurrent State RAM that retains hidden states across frames and features a synchronous clear port driven by the software flush command.


* **`activation_lut.sv`**: Contains pre-calculated 256-entry ROM Look-Up Tables (LUTs) for Sigmoid and Tanh non-linear activation mapping.


* **`rnn_pkg.sv`**: SystemVerilog package file containing shared constants and parameters for the RNN design.



### Verification & Simulation

* **`tb_phase3_stimulus.sv`**: The primary verification driver testbench. It generates the 50 MHz reference clock, drives AXI-Lite configuration registers, streams feature vectors, injects faults, and triggers state flushing.


* **`tb_phase3_light.sv` / `tb_top.sv` / `tb_voice_stability_monitor.sv**`: Supplementary SystemVerilog testbenches used for distinct hierarchical testing and module-level simulation.


* **`filelist.f`**: An argument compilation list that orders all design RTL components and the active testbench for Cadence Xcelium elaboration.


* **`power_activity.vcd` / `power_activity_stimulus.vcd**`: Cycle-accurate Value Change Dump waveforms capturing full-hierarchy toggle activity. These serve as the primary input for Cadence Genus to compute gate-level dynamic power dissipation.



### Synthesis & Physical Constraints

* **`run_synthesis.tcl`**: A structured Tcl control script that automates the Cadence Genus synthesis process, manages directory initialization, and executes the three-stage hierarchical optimization flow.


* **`constraints.sdc`**: Synopsys Design Constraints file establishing the electrical and temporal boundaries, including the 50 MHz reference clock, I/O delays, and environmental capacitive loading.


* **`voice_stability_monitor_top_*.rpt` (area, gates, power, qor, timing)**: Exported physical synthesis sign-off reports detailing footprint utilization, integrated clock gating efficiency, and pristine timing closure.



---

## How to Use

### 1. Functional Simulation

To verify the protocol compliance and arithmetic robustness, run the simulation environment using Cadence Xcelium.

* Ensure all RTL and testbench files are present.
* Pass the `filelist.f` script to Xcelium (e.g., using `xrun`) to elaborate and compile the design hierarchy.


* The simulation will generate the `power_activity_stimulus.vcd` file upon completion.



### 2. Logic Synthesis

To synthesize the RTL into a gate-level netlist targeted for a 90nm slow library:

* Launch Cadence Genus.


* Source the automation script by running `source run_synthesis.tcl`.


* The script will automatically compile the design, apply the `constraints.sdc`, perform timing optimizations, and ingest the `.vcd` files for power annotation.


* Review the generated `*.rpt` files for Area, Power, and Timing compliance.
