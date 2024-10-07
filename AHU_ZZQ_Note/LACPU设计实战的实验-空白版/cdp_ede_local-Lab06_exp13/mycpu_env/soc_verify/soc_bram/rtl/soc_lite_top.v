/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

//*************************************************************************
//   > File Name   : soc_top.v
//   > Description : SoC, included cpu, 2 x 3 bridge,
//                   inst ram, confreg, data ram
// 
//           -------------------------
//           |           cpu         |
//           -------------------------
//         inst|                  | data
//             |                  | 
//             |        ---------------------
//             |        |    1 x 2 bridge   |
//             |        ---------------------
//             |             |            |           
//             |             |            |           
//      -------------   -----------   -----------
//      | inst ram  |   | data ram|   | confreg |
//      -------------   -----------   -----------
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************

`default_nettype none

//for simulation:
//1. if define SIMU_USE_PLL = 1, will use clk_pll to generate cpu_clk/timer_clk,
//   and simulation will be very slow.
//2. usually, please define SIMU_USE_PLL=0 to speed up simulation by assign
//   cpu_clk/timer_clk = clk.
//   at this time, cpu_clk/timer_clk frequency are both 100MHz, same as clk.
`define SIMU_USE_PLL 0 //set 0 to speed up simulation
`include "vga.h"
module soc_lite_top #(parameter SIMULATION=1'b0)
(
    input  wire        resetn, 
    input  wire        clk,

    //------gpio-------
    output wire [15:0] led,//有
    input  wire [7 :0] switch, //ego1有
    input wire [7:0]hardware_interrupt_i,
   
   
   
    //input  wire [1 :0] btn_step,
    //数码管
    output wire [7:0]seg_cs_pin,
    output wire [7:0]seg_data_0_pin,
    output wire [7:0]seg_data_1_pin,
    //vga
     output wire vga_hs_o  ,            
     output wire vga_vs_o  ,            
     output wire [`VgaRgbWidth]vga_rgb_o
     //
//     output wire [3 :0] btn_key_col,  
//     input  wire [3 :0] btn_key_row,  
//     output  wire [31:0]inst,  
//     output wire [1 :0] led_rg0,     
//     output wire [1 :0] led_rg1,     
//     output wire [7 :0] num_csn,     
//     output wire [6 :0] num_a_g,     
//     output wire [31:0] num_data    
     
            
);
 wire [1 :0] btn_step;
 wire [3 :0] btn_key_col;  
 wire [3 :0] btn_key_row;  
 wire [31:0]inst        ;  
 wire [1 :0] led_rg0    ;     
 wire [1 :0] led_rg1    ;      
 wire [7 :0] num_csn    ;     
 wire [6 :0] num_a_g    ;     
 wire [31:0] num_data   ;


//debug signals
wire [31:0] debug_wb_pc;
wire [3 :0] debug_wb_rf_we;
wire [4 :0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;

//clk and resetn
wire cpu_clk;
wire timer_clk;
wire vga_clk;
wire locked;
//reg cpu_resetn;
//always @(posedge cpu_clk)begin
//        cpu_resetn <= resetn;
//    end generate if(SIMULATION && `SIMU_USE_PLL==0)begin: speedup_simulation
//        assign cpu_clk   = clk;
//        assign timer_clk = clk;
//    end else begin: pll
//        clk_pll clk_pll
//        (
//            .clk_in1 (clk),
            
//            .cpu_clk (cpu_clk),
//           // .vga_clk (vga_clk),
//            .timer_clk (timer_clk)
//            //.locked (locked)
//        );
//    end
//endgenerate

wire cpu_resetn;
assign cpu_resetn = resetn;
 clk_pll clk_pll             
 (                           
     .clk_in1 (clk),         
                             
     .cpu_clk (cpu_clk),     
     .vga_clk (vga_clk),   
     .timer_clk (timer_clk),  
     .locked (locked)      
 );                          


//cpu inst sram
wire        cpu_inst_en;
wire [3 :0] cpu_inst_we;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_wdata;
wire [31:0] cpu_inst_rdata;
//cpu data sram
wire        cpu_data_en;
wire [3 :0] cpu_data_we;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;

//data sram
wire        data_sram_en;
wire [3 :0] data_sram_we;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;
//video
wire        video_sram_en;
wire [3 :0] video_sram_we;
wire [31:0] video_sram_addr;
wire [31:0] video_sram_wdata;
wire [31:0] video_sram_rdata;
//conf
wire        conf_en;
wire [3 :0] conf_we;
wire [31:0] conf_addr;
wire [31:0] conf_wdata;
wire [31:0] conf_rdata;


//中断信号消=抖
wire [7:0]stable_hardware_interrupt_i;

 key_filter key_filter_item0
(
 .clk     (timer_clk ) ,//100Mhz
 .rst_l   (resetn)  ,
 .key_in  (hardware_interrupt_i[0]) ,
 .key_out (stable_hardware_interrupt_i[0])
);
                                             
 key_filter key_filter_item1                   
(                                             
 .clk     (timer_clk ) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[1]) ,         
 .key_out (stable_hardware_interrupt_i[1])    
);                                                                                          
 key_filter key_filter_item2                  
(                                             
 .clk     (timer_clk ) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[2]) ,         
 .key_out (stable_hardware_interrupt_i[2])    
);                                                                                      
 key_filter key_filter_item3                   
(                                             
 .clk     (timer_clk ) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[3]) ,         
 .key_out (stable_hardware_interrupt_i[3])    
);                                                                                  
 key_filter key_filter_item4                   
(                                             
 .clk     (timer_clk) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[4]) ,         
 .key_out (stable_hardware_interrupt_i[4])    
);                                            

 key_filter key_filter_item5                   
(                                             
 .clk     (timer_clk ) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[5]) ,         
 .key_out (stable_hardware_interrupt_i[5])    
);                                            
 key_filter key_filter_item6                   
(                                             
 .clk     (timer_clk ) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[6]) ,         
 .key_out (stable_hardware_interrupt_i[6])    
);                                            
 key_filter key_filter_item7                   
(                                             
 .clk     (timer_clk) ,//100Mhz                    
 .rst_l   (resetn)  ,                         
 .key_in  (hardware_interrupt_i[7]) ,         
 .key_out (stable_hardware_interrupt_i[7])    
);                                            



//cpu
//mycpu_top cpu(
//    .clk              (cpu_clk   ),
//    .resetn           (cpu_resetn),  //low active
Loog cpu(
    .clk              (cpu_clk   ),
    .rst_n           (cpu_resetn),  //low active
    .inst_sram_en     (cpu_inst_en   ),
    .inst_sram_we     (cpu_inst_we   ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
    
    .data_sram_en     (cpu_data_en   ),
    .data_sram_we     (cpu_data_we   ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata),
    //.hardware_interrupt_data(stable_hardware_interrupt_i),
    .hardware_interrupt_data(hardware_interrupt_i),

    //debug
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

//inst ram
inst_ram inst_ram
(
    .clka  (cpu_clk            ),   
    .ena   (cpu_inst_en        ),
    .wea   (cpu_inst_we        ),   //3:0
    .addra (cpu_inst_addr[19:2]),   //17:0
    .dina  (cpu_inst_wdata     ),   //31:0
    .douta (cpu_inst_rdata     )    //31:0
);

bridge_1x2 bridge_1x2(
    .clk             ( cpu_clk         ), // i, 1                 
    .resetn          ( cpu_resetn      ), // i, 1                 

    .cpu_data_en     ( cpu_data_en     ), // i, 4                 
    .cpu_data_we     ( cpu_data_we     ), // i, 4                 
    .cpu_data_addr   ( cpu_data_addr   ), // i, 32                
    .cpu_data_wdata  ( cpu_data_wdata  ), // i, 32                
    .cpu_data_rdata  ( cpu_data_rdata  ), // o, 32                

    .data_sram_en    ( data_sram_en    ), // o, 4                 
    .data_sram_we    ( data_sram_we    ), // o, 4                 
    .data_sram_addr  ( data_sram_addr  ), // o, `DATA_RAM_ADDR_LEN
    .data_sram_wdata ( data_sram_wdata ), // o, 32                
    .data_sram_rdata ( data_sram_rdata ), // i, 32 
    
    
    
    .video_sram_en    ( video_sram_en    ), // o, 4                          
    .video_sram_we    ( video_sram_we    ), // o, 4                          
    .video_sram_addr  ( video_sram_addr  ), // o, `DATA_RAM_ADDR_LEN         
    .video_sram_wdata ( video_sram_wdata ), // o, 32                         
    .video_sram_rdata ( video_sram_rdata ), // i, 32                                        

    .conf_en         ( conf_en         ), // o, 1                 
    .conf_we         ( conf_we         ), // o, 4                 
    .conf_addr       ( conf_addr       ), // o, 32                
    .conf_wdata      ( conf_wdata      ), // o, 32                
    .conf_rdata      ( conf_rdata      )  // i, 32                
 );

//data ram
data_ram data_ram
(
    .clka  (cpu_clk             ),   
    .ena   (data_sram_en        ),
    .wea   (data_sram_we        ),   //3:0
    .addra (data_sram_addr[17:2]),   //15:0
    .dina  (data_sram_wdata     ),   //31:0
    .douta (data_sram_rdata     )    //31:0
);

//confreg
confreg #(.SIMULATION(SIMULATION)) u_confreg
(
    .clk         ( cpu_clk    ),  // i, 1   
    .timer_clk   ( timer_clk  ),  // i, 1   
    .resetn      ( cpu_resetn ),  // i, 1    
    .conf_en     ( conf_en    ),  // i, 1      
    .conf_we     ( conf_we    ),  // i, 4      
    .conf_addr   ( conf_addr  ),  // i, 32        
    .conf_wdata  ( conf_wdata ),  // i, 32         
    .conf_rdata  ( conf_rdata ),  // o, 32         
    .led         ( led        ),  // o, 16   
    .led_rg0     ( led_rg0    ),  // o, 2      
    .led_rg1     ( led_rg1    ),  // o, 2      
    .num_csn     ( num_csn    ),  // o, 8      
    .num_a_g     ( num_a_g    ),  // o, 7      
    .num_data    ( num_data   ),  // o, 32
    .switch      ( switch     ),  // i, 8     
    .btn_key_col ( btn_key_col),  // o, 4          
    .btn_key_row ( btn_key_row),  // i, 4           
    .btn_step    ( btn_step   )   // i, 2   
);
//分频率器件
wire clk_1ms,clk_10ms, clk_100ms,clk_1s;
Clk_Div_Ms_S CDMS(
.clk      (timer_clk) ,
.rst_l    (resetn)  ,
.clk_1ms  (clk_1ms  )  ,
.clk_10ms (clk_10ms )  ,
.clk_100ms(clk_100ms)   ,
.clk_1s   (clk_1s   ) 
  );
//数码管nixie_tube
wire[3:0]sel_1;//控制右边4个4 3 2 1
wire[3:0]sel_2;//控制左边4个8 7 6 5
LED_display LD(
            .clk_1ms   (clk_1ms) ,
            .rst_l     (resetn)  ,
            .res       (num_data),
            .sel_1     (sel_1)    ,//控制右边4个4 3 2 1
            .sel_2     (sel_2)     ,//控制左边4个8 7 6 5
            .seg7_1    (seg_data_0_pin)      ,
            .seg7_2    (seg_data_1_pin)  
               );

assign seg_cs_pin = {sel_1,sel_2};




vga_colorbat vga_colorbat_item(
  .vga_clk     (vga_clk)  ,
  .rst_n   ( cpu_resetn) ,
  .locked   (locked),
  
  
  .cpu_clk                ( cpu_clk )     ,
  .cpu_video_memory_en_i  ( video_sram_en   )   ,
  .cpu_video_memory_we_i  ( video_sram_we   )   ,
  .cpu_video_rwaddr_i     ( video_sram_addr )   ,
  .cpu_video_wdata_i      ( video_sram_wdata)   ,
  .cpu_video_rdata_o      ( video_sram_rdata)   ,
  
  .vga_hs_o (vga_hs_o ) ,
  .vga_vs_o (vga_vs_o ) ,
  .vga_rgb_o(vga_rgb_o)
);


assign inst=cpu_inst_rdata;
endmodule

