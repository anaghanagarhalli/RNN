// scripts/tb/filelist.f

// Package definitions (must be compiled first)
../rtl/rnn_pkg.sv

// RTL Modules
../rtl/reg_file.sv
../rtl/axi_stream_receiver.sv
../rtl/hidden_state_mem.sv
../rtl/rnn_compute_engine.sv
../rtl/activation_lut.sv
../rtl/post_process_alert.sv
../rtl/voice_stability_monitor_top.sv

// Testbench
tb_phase3_stimulus.sv
tb_phase3_light.sv
tb_voice_stability_monitor.sv
