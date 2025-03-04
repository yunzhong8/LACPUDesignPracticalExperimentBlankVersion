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
//for func test, no define RUN_PERF_TEST
//sb东西,写模块不写模块逻辑的都是sb，你不写我咋知道如何和你的sb对接呢，你个够吧东西，现在我看书就对接错啦，为什么addr_ok会tm一直输出呢，你个sb
`define _RUN_PERF_TEST

module sram_wrap(
  input  wire        clk,
  input  wire        resetn,

  input  wire        req    ,
  input  wire        wr     ,
  input  wire [1 :0] size   ,
  input  wire [3 :0] wstrb  ,
  input  wire [31:0] addr   ,
  input  wire [31:0] wdata  ,
  output wire        addr_ok,
  output wire        data_ok,
  output wire [31:0] rdata  ,

  //slave
  output wire        ram_en   ,
  output wire [3 :0] ram_we   ,
  output wire [31:0] ram_addr ,
  output wire [31:0] ram_wdata,
  input  wire [31:0] ram_rdata,
  //from confreg
  input  wire [1 :0] ram_random_mask
);
wire addr_and;
wire data_and;
//mask
`ifdef RUN_PERF_TEST
    assign addr_and = 1'b1;
    assign data_and = 1'b1;
`else
    assign addr_and = ram_random_mask[1];
    assign data_and = ram_random_mask[0];
`endif
     
//to ram
wire [3:0] size_decode = size==2'd0 ? {addr[1:0]==2'd3,addr[1:0]==2'd2,addr[1:0]==2'd1,addr[1:0]==2'd0} :
                         size==2'd1 ? {addr[1],addr[1],~addr[1],~addr[1]} :
                                      4'hf;
assign ram_en    = req && addr_ok;
assign ram_we    = {4{wr}} & wstrb & size_decode;
assign ram_addr  = addr;
assign ram_wdata = wdata;

//缓存一级指令存储器使能信号
reg ram_en_r;
//延迟一个时钟周期是因为sram是时序读写，sram当前时钟周期接收到ram_en，下一时钟周期就会返回读出数据就是正好是ram_en_r=1的时候
always @(posedge clk)
begin
    ram_en_r <= ram_en;
end

//buf of rdata from ram
reg [2 :0] buf_wptr;
reg [2 :0] buf_rptr;
reg [31:0] buf_rdata [3:0];

//写指针==读指针表明fifo是空的
wire  buf_empty   = buf_wptr==buf_rptr;
//写指针
wire  buf_full    = buf_wptr=={~buf_rptr[2],buf_rptr[1:0]};
//return data_ok in next clock.
wire  fast_return = ram_en_r && data_ok && buf_empty;

always @(posedge clk)begin
    //指令fifo写地址
    if(!resetn)begin
        buf_wptr <= 3'd0;
    end else if(ram_en_r && !fast_return)begin//
        buf_wptr <= buf_wptr + 1'b1;
    end
    
    //指令fifo，当当前时钟周期sram读出数据，但是但fifo不是空的则将读出数据写入fifo
    if(ram_en_r && !fast_return)begin
        buf_rdata[buf_wptr[1:0]] <= ram_rdata;
    end
    
    //指令fifo读地址指针
    if(!resetn)begin
        buf_rptr <= 3'd0;
    end else if(!buf_empty && data_ok) begin
        buf_rptr <= buf_rptr + 1'b1;
    end
end
//addr_ok
//addr_and,是随机延迟，
//地址ok的输出1的条件是：当前时钟周期没有出现随机延迟，且指令缓存区没有满
assign addr_ok = 1'b1 && addr_and && !buf_full;
//data_ok
//当当前时周期fifo中有数据，或者当前sram读出数据，则返回地址ok
assign data_ok = 1'b1 && data_and &&(!buf_empty||ram_en_r);
//rdata
//当fifo不是空的时候，这选用fifo的数据作为返回数据。
assign rdata   = buf_empty ? ram_rdata : buf_rdata[buf_rptr[1:0]];

endmodule
