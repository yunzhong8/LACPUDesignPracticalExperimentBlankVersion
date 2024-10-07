`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/16 18:47:18
// Design Name: 
// Module Name: define
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define TlbItemNum 8
//////////////////////虚拟
`define EnLen 1
//虚拟页号
`define VppnLen 19
`define VppnWidth `VppnLen-1 :0

//页大小
`define PsLen 6
`define PsWidth `PsLen-1 :0

//全局使能位
`define GLen 1
`define GWidth `GLen-1 :0

//地址对应进程id
`define AsidLen 10
`define AsidWidth `AsidLen -1 :0
//查找无效位置
`define ELen 1
`define EWidth `Elne-1 :0


/////////////////////////物理
//物理页号
`define PpnLen 20
`define PpnWidth `PpnLen-1 :0

//表项对应权限
`define PlvLen 2
`define PlvWidth `PlvLen-1 :0
//表项空间对应的存储访问类型
`define MatLen 2
`define MatWidth `MatLen-1:0

//肮脏数据位
`define DLen  1
`define DWidth `DLen-1 :0
//数据有效位
`define VLen 1
`define VWidth `VLen-1:0

//TLB表项定义
`define TlbVirtualItemLen `VppnLen + `PsLen +`GLen +`AsidLen +`ELen 
`define TlbPhysicsItemLen `PpnLen + `PlvLen +`MatLen+`DLen+`VLen
`define TLbItemLen `TlbVirtualItemLen + `TlbPhysicsItemLen + `TlbPhysicsItemLen

`define TlbIndexLen 4
`define TlbIndexWidth `TlbIndexLen -1 :0  
//TLB读写长度定义
//`define TlbVirtualWRLen `VppnLen + `PsLen +`GLen +`AsidLen +`ELen 
//`define TlbPhysicsWRLen `PpnLen + `PlvLen +`MatLen+ `DLen + `VLen

//总线
//查找输入bus
`define TlbSearchIbusLen `VppnLen + `EnLen +`AsidLen 
`define TlbSearchIbusWidth `TlbSearchIbusLen-1 : 0
//查找输出bus
`define TlbSearchObusLen  `TlbIndexLen +`PpnLen +`PsLen +`PlvLen +`MatLen +`EnLen + `EnLen
`define TlbSearchObusWidth  `TlbSearchObusLen-1 : 0
//写bus
`define TlbWriteBusLen  `TlbVirtualItemLen + `TlbPhysicsItemLen + `TlbPhysicsItemLen
`define TlbWriteBusWidth `TlbWriteBusLen-1 :0
//读输入bus
`define TlbReadIbusLen `TlbIndexLen 
`define TlbReadIbusWidth `TlbReadIbusLen-1 :0
//读输出bus
`define TlbReadObusLen  `TlbVirtualItemLen + `TlbPhysicsItemLen + `TlbPhysicsItemLen
`define TlbReadObusWidth `TlbReadObusLen-1 :0
//地址定义


