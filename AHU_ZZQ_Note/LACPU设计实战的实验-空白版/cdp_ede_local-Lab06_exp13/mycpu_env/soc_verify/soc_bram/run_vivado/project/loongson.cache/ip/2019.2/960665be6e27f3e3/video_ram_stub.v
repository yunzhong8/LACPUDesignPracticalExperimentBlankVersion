// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (lin64) Build 2708876 Wed Nov  6 21:39:14 MST 2019
// Date        : Tue Apr 25 23:35:34 2023
// Host        : nb running 64-bit Ubuntu 22.04.2 LTS
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ video_ram_stub.v
// Design      : video_ram
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clka, ena, wea, addra, dina, douta, clkb, enb, web, addrb, 
  dinb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[1:0],addra[12:0],dina[15:0],douta[15:0],clkb,enb,web[1:0],addrb[12:0],dinb[15:0],doutb[15:0]" */;
  input clka;
  input ena;
  input [1:0]wea;
  input [12:0]addra;
  input [15:0]dina;
  output [15:0]douta;
  input clkb;
  input enb;
  input [1:0]web;
  input [12:0]addrb;
  input [15:0]dinb;
  output [15:0]doutb;
endmodule
