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
`timescale 1ns / 1ps

`define TRACE_REF_FILE "/home/ysyx/zzq/cdp_ede_local-Lab06_exp13/mycpu_env/gettrace/golden_trace.txt"
`define CONFREG_NUM_REG      soc_lite.u_confreg.num_data
`define CONFREG_OPEN_TRACE   soc_lite.u_confreg.open_trace
`define CONFREG_NUM_MONITOR  soc_lite.u_confreg.num_monitor
`define CONFREG_UART_DISPLAY soc_lite.u_confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.u_confreg.write_uart_data
`define END_PC 32'h1c000100

module tb_top( );
reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [1 :0] led_rg0;
wire [1 :0] led_rg1;
wire [7 :0] num_csn;
wire [6 :0] num_a_g;
wire [7 :0] switch;
wire [3 :0] btn_key_col;
wire [3 :0] btn_key_row;
wire [1 :0] btn_step;
reg[7:0]hardware_interrupt;
assign switch      = 8'hff;
assign btn_key_row = 4'd0;
assign btn_step    = 2'd3;


wire [31:0] inst;
initial
begin
    $dumpfile("dump.vcd");
    $dumpvars;
    clk = 1'b0;
    resetn = 1'b0;
    hardware_interrupt = 8'd0;
    #2000;//2000ns复位
    resetn = 1'b1;
    #3000000//3ms发生中断
    hardware_interrupt = 8'b0000_0001;
    #500
    hardware_interrupt = 8'b0000_0000;
    #10000
    hardware_interrupt = 8'b0000_0010;
    #500
    hardware_interrupt = 8'b0000_0000;
    #10000
    hardware_interrupt = 8'b0000_0100;
    #500
    hardware_interrupt = 8'b0000_0000;
    #10000
    hardware_interrupt = 8'b0000_1010;
    #500
    hardware_interrupt = 8'b0000_0000;
    #10000                                
    hardware_interrupt = 8'b0001_0000;    
    #500                                  
    hardware_interrupt = 8'b0000_0000;  
    #10000                                   
    hardware_interrupt = 8'b0010_0000;     
    #500                                   
    hardware_interrupt = 8'b0000_0000;  
    #10000                                 
    hardware_interrupt = 8'b0100_0000;      
    #500                                     
    hardware_interrupt = 8'b0000_0000;   
    #10000                                 
    hardware_interrupt = 8'b1000_0000;      
    #500                                     
    hardware_interrupt = 8'b0000_0000;    
      
    
end
always #5 clk=~clk;
soc_lite_top #(.SIMULATION(1'b1)) soc_lite
(
       .resetn      (resetn     ), 
       .clk         (clk        ),
    
        //------gpio-------
        //.num_csn    (num_csn    ),
        //.num_a_g    (num_a_g    ),
        .led        (led        ),
        //.led_rg0    (led_rg0    ),
        //.led_rg1    (led_rg1    ),
        .switch     (switch     ),
        //.btn_key_col(btn_key_col),
        //.btn_key_row(btn_key_row),
        //.inst        (inst),//zzq添加的
        //.btn_step   (btn_step   )
        .hardware_interrupt_i(hardware_interrupt)
    );   
//integer handle1,handle2;
//initial
//    begin
//        //r方式，被读的文件，用于获取激励信号输入值
//        //handle1= $fopen("D:/Documents/Hardware_verlog/Teacher_example/txt/51.txt","r");
//        //w方式，被写入的文件，用于写入系统函数的输出值
//        handle2= $fopen("/home/zzq/code/Python/Module/inst.txt","w");
//        //设置输出值显示在控制台上
//        handle2=handle2|32'h0000_0001;
//        #2015
//        //输出题头
//        //$fdisplay(handle2,"time \t,a\t,b\t,c\t,Input\t,output\t");
//        while(!$feof(handle2))
//            begin
//                //#49  $fscanf(handle1,"%b%b%b%b",a,b,c,I);//每个49个时间单位更新一次激励信号
//                //再过1个时间单位输出系统函数数据
//                //#10 $fdisplay(handle2,$time,,"%h",inst);
//                //#10 $display(handle2,$time,,"%h",inst);
//            end
//        //再前面的循环完成后关闭文件
//        $fclose(handle2);
//        //$fclose(handle1);
//    end
    
//soc lite signals
//"soc_clk" means clk in cpu
//"wb" means write-back stage in pipeline
//"rf" means regfiles in cpu
//"w" in "wen/wnum/wdata" means writing
wire soc_clk;
wire [31:0] debug_wb_pc;
wire [3 :0] debug_wb_rf_we;
wire [4 :0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
assign soc_clk           = soc_lite.cpu_clk;
assign debug_wb_pc       = soc_lite.debug_wb_pc;
assign debug_wb_rf_we    = soc_lite.debug_wb_rf_we;
assign debug_wb_rf_wnum  = soc_lite.debug_wb_rf_wnum;
assign debug_wb_rf_wdata = soc_lite.debug_wb_rf_wdata;

// open the trace file;
integer trace_ref;
initial begin
    trace_ref = $fopen(`TRACE_REF_FILE, "r");
end

//get reference result in falling edge
reg        trace_cmp_flag;
reg        debug_end;

reg [31:0] ref_wb_pc;
reg [4 :0] ref_wb_rf_wnum;
reg [31:0] ref_wb_rf_wdata;

integer a;
always @(posedge soc_clk)
begin 
    #1;
    if(|debug_wb_rf_we && debug_wb_rf_wnum!=5'd0 && !debug_end && `CONFREG_OPEN_TRACE)
    begin
        trace_cmp_flag=1'b0;
        while (!trace_cmp_flag && !($feof(trace_ref)))
        begin
            a = $fscanf(trace_ref, "%h %h %h %h", trace_cmp_flag,
                    ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata);
        end
    end
end

//wdata[i*8+7 : i*8] is valid, only wehile wen[i] is valid
wire [31:0] debug_wb_rf_wdata_v;
wire [31:0] ref_wb_rf_wdata_v;
assign debug_wb_rf_wdata_v[31:24] = debug_wb_rf_wdata[31:24] & {8{debug_wb_rf_we[3]}};
assign debug_wb_rf_wdata_v[23:16] = debug_wb_rf_wdata[23:16] & {8{debug_wb_rf_we[2]}};
assign debug_wb_rf_wdata_v[15: 8] = debug_wb_rf_wdata[15: 8] & {8{debug_wb_rf_we[1]}};
assign debug_wb_rf_wdata_v[7 : 0] = debug_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_we[0]}};
assign   ref_wb_rf_wdata_v[31:24] =   ref_wb_rf_wdata[31:24] & {8{debug_wb_rf_we[3]}};
assign   ref_wb_rf_wdata_v[23:16] =   ref_wb_rf_wdata[23:16] & {8{debug_wb_rf_we[2]}};
assign   ref_wb_rf_wdata_v[15: 8] =   ref_wb_rf_wdata[15: 8] & {8{debug_wb_rf_we[1]}};
assign   ref_wb_rf_wdata_v[7 : 0] =   ref_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_we[0]}};


//compare result in rsing edge 
reg debug_wb_err;
always @(posedge soc_clk)begin
    #2;
    if(!resetn)begin
        debug_wb_err <= 1'b0;
        $display("复位中[%t]",$time);
    end else if(|debug_wb_rf_we && debug_wb_rf_wnum!=5'd0 && !debug_end && `CONFREG_OPEN_TRACE)begin
        //如果mycpu和正确的轨迹reg_xxx不同则打印数据，通过finish并暂停仿真
        //$display("trance对比[%t]grace--pc=%h,zzqcpu_pc=%h",$time,ref_wb_pc,debug_wb_pc);
        if (  (debug_wb_pc!==ref_wb_pc) || (debug_wb_rf_wnum!==ref_wb_rf_wnum)
            ||(debug_wb_rf_wdata_v!==ref_wb_rf_wdata_v) )begin
            $display("--------------------------------------------------------------");
            $display("还没有开始比对[%t]debug_wb=%b,debug_wb_rf_wnum=%d,debug_end=%b",$time,|debug_wb_rf_we,debug_wb_rf_wnum,!debug_end);
            $display("[%t] Error!!!",$time);
            $display("    reference: PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
            $display("    mycpu    : PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata_v);
            $display("--------------------------------------------------------------");
            debug_wb_err <= 1'b1;
            #40;//过40ns暂停流水，即4个四个时钟周期
           // $fclose(handle2);
          //  $finish;//错误就停止仿真
        end
    end else  begin
        //$display("还没有开始比对[%t]debug_wb=%b,debug_wb_rf_wnum=%d,debug_end=%b",$time,|debug_wb_rf_we,debug_wb_rf_wnum,!debug_end);
    end
end

//monitor numeric display，检测外部设备访问是否错误
reg [7:0] err_count;
wire [31:0] confreg_num_reg = `CONFREG_NUM_REG;
reg  [31:0] confreg_num_reg_r;
always @(posedge soc_clk)
begin
    confreg_num_reg_r <= confreg_num_reg;
    if (!resetn)
    begin
        err_count <= 8'd0;
    end
    else if (confreg_num_reg_r != confreg_num_reg && `CONFREG_NUM_MONITOR)
    begin
        if(confreg_num_reg[7:0]!=confreg_num_reg_r[7:0]+1'b1)
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Occurred in number 8'd%02d Functional Test Point!",$time, err_count, confreg_num_reg[31:24]);
            $display("--------------------------------------------------------------");
            err_count <= err_count + 1'b1;
        end
        else if(confreg_num_reg[31:24]!=confreg_num_reg_r[31:24]+1'b1)
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Unknown, Functional Test Point numbers are unequal!",$time,err_count);
            $display("--------------------------------------------------------------");
            $display("==============================================================");
            err_count <= err_count + 1'b1;
        end
        else
        begin
            $display("----[%t] Number 8'd%02d Functional Test Point PASS!!!", $time, confreg_num_reg[31:24]);
        end
    end
end

//monitor test
initial
begin
    $timeformat(-9,0," ns",10);
    while(!resetn) #5;
    $display("==============================================================");
    $display("Test begin!");

    #10000;
    while(`CONFREG_NUM_MONITOR)
    begin
        #10000;
        $display ("        [%t] Test is running, debug_wb_pc = 0x%8h",$time, debug_wb_pc);
    end
end

//模拟串口打印
wire uart_display;
wire [7:0] uart_data;
assign uart_display = `CONFREG_UART_DISPLAY;
assign uart_data    = `CONFREG_UART_DATA;

always @(posedge soc_clk)
begin
    if(uart_display)
    begin
        if(uart_data==8'hff)
        begin
            ;//$finish;
        end
        else
        begin
            $write("%c",uart_data);
        end
    end
end

//test end
wire global_err = debug_wb_err || (err_count!=8'd0);
wire test_end = (debug_wb_pc==`END_PC) || (uart_display && uart_data==8'hff);
always @(posedge soc_clk)
begin
    if (!resetn)
    begin
        debug_end <= 1'b0;
    end
    else if(test_end && !debug_end)
    begin
        debug_end <= 1'b1;
        $display("==============================================================");
        $display("Test end!");
        #40;
        $fclose(trace_ref);
        if (global_err)
        begin
            $display("Fail!!!Total %d errors!",err_count);
        end
        else
        begin
            $display("----PASS!!!");
        end
	   // $finish;
	end
end


endmodule
