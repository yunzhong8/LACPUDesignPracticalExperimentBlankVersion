`timescale 1ns / 1ps
/*
*作者：zzq
*创建时间：2023-03-31
*email:3486829357@qq.com
*github:yunzhong8
*输入：
*输出：
*模块功能：实现的是一个2路组相联的cache,
*每一路的大小4KB
*使用的是随机替换的路策略
*读命中:需要两个时钟周期读出数据
*读未命中:需要至少5个时钟周期,最多:9个时钟周期
*写命中:2个时钟周期,(3实际使用了3个时钟周期),只是第3个时钟周期如果不是访存指令是不会阻塞CPU流水线的
*写未命中:2个时钟周期(实际使用最多时钟周期),只是在2~9过程中如果不出现访存指令是不会阻塞CPU流水
*/
/*************\
bug:
\*************/
//写会外部需要检测当前是否是脏数据，我没检查，只要miss就写回
//实现
`include"define.v"
module cache(
 input  wire                         clk                ,
 input  wire                         resetn             ,
 input  wire                         valid              ,//访问请求信号req，1表示有请求
 input  wire                         op                 ,//访问类型，0：req,1:write,we信号
 input  wire [`CacheOffsetWidth]     offset             ,//pc[3:0]
 input  wire [`CacheIndexWidth]      index              ,//pc[11:4]
 input  wire [`CacheTagWidth]        tag                ,//p_pc[31:12]

 input  wire [`CacheWstrbWidth]      wstrb              ,//写字节使能
 input  wire [31:0]                  wdata              ,//cache写数据
                                                    
 output reg                          addr_ok            ,//输出已经接收地址ok
 output reg                          data_ok            ,//输出数据准备好啦
 output wire [31:0]                  rdata              ,//输出读出数据
                                                        
 output reg                          rd_req             ,//输出类AXI读请求
 output wire [2:0]                   rd_type            ,//输出类AXI读请求类型
 output wire [31:0]                  rd_addr            ,//输出类AXI读请求的起始地址
 input  wire                         rd_rdy             ,//AXI转接桥输入可以读啦，read_ready
 input  wire                         ret_valid           ,//axi转接桥输入读回数据read_data_valid
 input  wire                         ret_last           ,//axi转接桥输入这是最后一个读回数据，为什么是两位的？？？？
 input  wire [31:0]                  ret_data           ,//axi转接桥输入的读回数据
                                                        
 output reg                          wr_req             ,//类AXI输出的写请求
 output wire [2:0]                   wr_type            ,//类AXI输出的写请求类型
 output wire [31:0]                  wr_addr            ,//类AXI输出的写地址
 output wire [3:0]                   wr_wstrb           ,//写操作掩码
 output wire  [`CacheBurstDataWidth] wr_data            ,//类AXI输出的写数据128bit       
 input  wire                         wr_rdy              //AXI总线输入的写完成信号，可以接收写请求                     
    );
  
  
  /***************************************input variable define(输入变量定义)**************************************/
  /***************************************output variable define(输出变量定义)**************************************/
   wire[`CacheTagWidth]       wr_addr_tag_o   ;//cache写外部axi的标记字段p_pc[31:12]
   wire [`CacheIndexWidth]    wr_addr_index_o ;//pc[11:4]
   wire [`CacheOffsetWidth]   wr_addr_offset_o;//p_pc[31:12] 
  
  
  /***************************************parameter define(常量定义)**************************************/  
  parameter RIDLE      = 3'b000;//0
  parameter LOOKUP     = 3'b001;//1
  parameter MISS       = 3'b010;//2
  parameter WRITEBACK  = 3'b011;//3
  parameter REPLACE    = 3'b100;//4
  parameter REFILL     = 3'b101;//5
  parameter WRITE      = 3'b110;//6
  reg [2:0]r_cs,r_ns;
    
    
  /***************************************inner variable define(内部变量定义)**************************************/ 
  //缓存变量定义
   reg          search_addr_buffer_we  ;//缓存地址写使能    
   reg  [31:0]  search_addr_buffer     ;
         
   reg          search_buffer_we       ;      
   reg  [299:0] search_buffer          ;//查找缓存区/      
                
   reg          cache_wway_buffer_we   ; 
   reg          cache_wway_buffer      ;
                      
   reg          cache_wdata_buffer_we  ;  
   reg [31:0]   cache_wdata_buffer     ;//缓存写数据  
   reg [3:0]    cache_wstr_buffer      ;//缓存写字节使能     
   
  //缓存外部axi传入数据   
   wire [31:0] ret_wrote_data          ;//返回的是已经写入的数据  
   reg         axi_write_count_we      ; 
   reg  [1:0]  axi_write_count         ;//4个字 
   reg  [31:0] exrt_axi_rdata_buffer0,exrt_axi_rdata_buffer1,exrt_axi_rdata_buffer2;     
   
  //CacheTable需要的变量
   wire         cache_re,cache_we      ;//cache请求：写使能，读使能
   reg          cache_search_op        ;//查找类型
   wire [299:0] cache_rdata            ;
   wire [149:0] cache_wdata            ;//cache待写回数据(只写一路的，所以是150)
   wire [31:0]  w_data0                ;
   wire [127:0] w_data                 ;//写回的128bit数据
   wire [19:0]  w_tag                  ;
   wire         w_v                    ;
   wire         w_d                    ;      
  //cache信号
   reg                     cache_en           ;//cache使能信号
   reg  [1:0]              cache_wtype        ;
   wire [`CacheIndexWidth] cache_rindex       ;
   wire                    cache_wway         ;//cache写的路
   wire [`CacheIndexWidth] cache_w_index      ;//cache写的地址   
  //CacheMiss信号 
   reg                     miss_replace_way   ;
   reg                     miss_replace_way_we    ;    
  //查找命中信号
   wire                    way1_cache_hit,way0_cache_hit; 
  //随机数产生器
   reg                     rand_count;  
   /***************************************inner variable define(逻辑实现)**************************************/  
  /******************************inner variable define(缓存实现)*******************************/  
  //缓存访问cache的地址
    always @(posedge clk )begin
        if(resetn ==1'b0)begin
           search_addr_buffer <= 32'd0;
           cache_search_op <= 1'b0 ;
       end else if (search_addr_buffer_we)begin
           search_addr_buffer <= { tag,index,offset};
           cache_search_op <= op ;
       end
    end
    
  //缓存cache查找出的数据
  //当有读请求且要响应的时候，则将读出数据缓存到search_buffer中  
  //1：只有读命中的时候有新请求，该值才会被修改
  //2:当当前状态机处于空状态的时候，遇到请求，该值会被修改
    always @(posedge clk)begin
       if(resetn ==1'b0)begin
           search_buffer <= 300'd0;
       end else if (search_buffer_we)begin
           search_buffer = cache_rdata;
       end
    end 
    
  //缓存cpu写cache的数据
    always @(posedge clk)begin
        //缓存读写路的id
       if(resetn == 1'b0)begin
           cache_wway_buffer = 1'b0;
        end else if (cache_wway_buffer_we & way0_cache_hit)begin//查找命中的话，则根据查找出的数据所在路作为写入路
            cache_wway_buffer = 1'b0;
        end else if (cache_wdata_buffer_we & way1_cache_hit)begin
            cache_wway_buffer = 1'b1;
        end else if (cache_wdata_buffer_we &~way0_cache_hit& ~way1_cache_hit)begin//没有命中本处固定为0（本来应该是随机的）
            cache_wway_buffer = 1'b0;
        end else begin
            cache_wway_buffer = cache_wway_buffer;
        end
      //缓存：写入cache的数据,字节使能
       if(resetn == 1'b0)begin
            cache_wdata_buffer  = 32'd0;
            cache_wstr_buffer   = 4'd0;
       end else if(cache_wdata_buffer_we)begin
           cache_wdata_buffer = wdata;
           cache_wstr_buffer   = wstrb ;
       end
    end
 
 
 
 //如果cpu写块内地址和当传入数据的块地址相同，则进行修改
 assign ret_wrote_data = (cache_search_op && search_addr_buffer[3:2]== axi_write_count) ?  (cache_wstr_buffer==4'b1111 ? cache_wdata_buffer :                                                     
                                                                      cache_wstr_buffer==4'b1100 ? {cache_wdata_buffer[31:16],ret_data[15:0]}:                               
                                                                      cache_wstr_buffer==4'b0011 ? {ret_data[31:16],cache_wdata_buffer[15:0]}:                               
                                                                      cache_wstr_buffer==4'b1000 ? {cache_wdata_buffer[31:24],ret_data[23:0]}:                               
                                                                      cache_wstr_buffer==4'b0100 ? {ret_data[31:24],cache_wdata_buffer[23:16],ret_data[15:0]}:               
                                                                      cache_wstr_buffer==4'b0010 ? {ret_data[31:16],cache_wdata_buffer[15:8],ret_data[7:0]}:                 
                                                                      cache_wstr_buffer==4'b0001 ? {ret_data[31:8],cache_wdata_buffer[7:0],ret_data[7:0]}:ret_data[31:0]) :ret_data[31:0] ;    
 
 //缓存：axi读回128个字节数据
    always @(posedge clk)begin
        //接收外界axi的数据计数器
       if(resetn == 1'b0)begin
           axi_write_count <= 2'd0;//初始值为0
       end else if(axi_write_count_we)begin//因为不是按照周期进行计数的所以要设置计数使能信号
           axi_write_count <= axi_write_count+1;
       end else begin
           axi_write_count <= axi_write_count;
       end
    
       //缓存[31:0]
       if(resetn == 1'b0)begin
           exrt_axi_rdata_buffer0 <= 32'd0;
       end else if (2'd0 == axi_write_count[1:0] )begin
           exrt_axi_rdata_buffer0 <= ret_wrote_data;
       end else begin
           exrt_axi_rdata_buffer0 <= exrt_axi_rdata_buffer0;
       end
       //缓存[63:32]
        if(resetn == 1'b0)begin
           exrt_axi_rdata_buffer1 <= 32'd0;
       end else if (2'd1 == axi_write_count[1:0] )begin
           exrt_axi_rdata_buffer1 <= ret_wrote_data;
       end else begin
           exrt_axi_rdata_buffer1 <= exrt_axi_rdata_buffer1;
       end
       //缓存[95:64]
       if(resetn == 1'b0)begin
           exrt_axi_rdata_buffer2 <= 32'd0;
       end else if (2'd2 == axi_write_count[1:0])begin
           exrt_axi_rdata_buffer2 <= ret_wrote_data;
       end else begin
           exrt_axi_rdata_buffer2 <= exrt_axi_rdata_buffer2;
       end
       
    end
    

 
 //随机way_id产生器
    always @(posedge clk)begin
       if(resetn == 1'b0)begin
          rand_count <= 1'b0;
       end else begin
          rand_count <= rand_count +1;
       end
    end
  
 //缓存没有命中的替换的地址,和路id
    always @(posedge clk)begin
       if(resetn == 1'b0)begin
           miss_replace_way   <= 1'b0;
       end else if(miss_replace_way_we)begin
           miss_replace_way  <= rand_count;
       end else begin
           miss_replace_way   <= miss_replace_way   ;  
       end
    end
 
 //查找比较电路
 //当标记相等，且v字有效，则为查找成功
    assign way0_cache_hit =   search_addr_buffer [31:12] == search_buffer[`Way0TagLocation] && search_buffer[`Way0VLocation];
    assign way1_cache_hit =   search_addr_buffer [31:12] == search_buffer[`Way1TagLocation] && search_buffer[`Way1VLocation];
    
 //当前cache请求类型   
    assign cache_re = valid&~op;
    assign cache_we = valid&op;
    assign no_cache_req =  ~valid;
 
 //cache写数据
    assign cache_rindex = (r_cs==MISS)?  search_addr_buffer[11:4]:index;//读地址
    
    assign w_tag = search_addr_buffer[31:12];//无论是否命中，tag位都是查找地址的[31:12
    assign w_v = 1'b1;// 有效位,全写的时候设置为1,部分写不需要设在v字段
    assign w_d =  cache_search_op ? 1'd1 :1'd0;//只有部分写的时候d=1,全写则d=0（由于是写缺失导致的全写模式也要设置d=1,所以应该是当前cache的请求是store则，为1,否则=0） 
    //规定当状态是write的时候低32是CPU写入数据
    assign w_data0 = (r_cs==WRITE)? cache_wdata_buffer:exrt_axi_rdata_buffer0;
    assign w_data = {ret_wrote_data,exrt_axi_rdata_buffer2,exrt_axi_rdata_buffer1,w_data0};
    assign cache_wdata = {{w_v,w_tag},w_data,w_d};
 

 //替换的时候,写入外部axi的数据
    assign wr_type = 3'b100;//请求类型固定只能是行请求
    assign wr_wstrb = cache_wstr_buffer;
    assign wr_addr_index_o = search_addr_buffer[11:4];
    assign wr_addr_offset_o =  4'd0;
 //查找缺失的时候
 //替换的时候，是被替换行的地址
 //如果随机选择的way=1则是search_buffer[`Way1TagLocation]，cache_way是和wr_addr_tag同时钟产生的，没有落后于wr_addr_tag
    assign wr_addr_tag_o = cache_wway ? search_buffer[`Way1TagLocation] :  search_buffer[`Way0TagLocation];
    
 //标记是要被替换的way中的，index是查询地址的，初始位是0000
    assign wr_addr = {wr_addr_tag_o,wr_addr_index_o,4'd0};//查找地址必须是物理地址
    assign rd_addr = search_addr_buffer;
    assign wr_data = miss_replace_way ? search_buffer[`Way1DataLocation] : search_buffer[`Way0DataLocation];//只选用查找缓存区的way0作为替换                   
 
                        
 //主状态机   
 //有关信号
 /*
 cache请求
 cache_en :now_clk是否要使用cache_table
 cache_wtype：00：读请求，01：cpu写cache请求，10：外部axi读出数据进行替换写
 
 查找地址缓存
 search_addr_buffer_we 将cpu查找cache地址进行缓存
 CPU写数据缓存
 cache_wdata_buffer_we 将cpu要写入cache的数据进行缓存
 cache查找数据缓存
 search_buffer_we 将读查找出的数据进行缓存
 //随机替换的路id缓存
 cache_wway_buffer_we 将命中的路id进行缓存，或者缓存要替换的路
 
 addr_ok ：是否接收了cpu的请求
 data_ok：cache是否读出数据

 wr_req ;//向外部aix发出写请求                               
 wr_data //只选用查找缓存区的way0作为替换  
 miss_replace_we //发生miss设置随机读写地址和随机读写way
 
 rd_req 向外部axi发出读请求
 axi_write_count_we 接收外部axi的传入数据的计数器
 r_ns：下一个状态
 */
 always @(*)begin
    case(r_cs)
        RIDLE:begin
            if(cache_we)begin//有写请求
                cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求
                cache_wtype = 2'b00;//不发生写
                
                search_addr_buffer_we = 1'b1;//将查找地址进行缓存
                cache_wdata_buffer_we = 1'b1;//将写数据进行缓存
                search_buffer_we = 1'b1;//缓存cache查找出的数据
                cache_wway_buffer_we = 1'd0;
               
                addr_ok = 1'b1;//返回地址ok，表示请求已经接收啦
                data_ok = 1'b0;
              
                
                wr_req = 1'b0;//向外部aix发出写请求                               
                miss_replace_way_we = 1'b0;
                
                rd_req = 1'b0;
                axi_write_count_we=1'b0;
                
                r_ns = LOOKUP;
            end else if(cache_re)begin//有读请求  
                cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求
                cache_wtype = 2'b00;//不发生写

                search_addr_buffer_we = 1'b1;//将查找地址进行缓存
                cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                search_buffer_we = 1'b1;//缓存cache查找出的数据
                cache_wway_buffer_we = 1'd0;
                
                addr_ok = 1'b1;
                data_ok = 1'b0;
              
                
                wr_req = 1'b0;//向外部aix发出写请求                               
                miss_replace_way_we = 1'b0; 
                
                rd_req = 1'b0;
                axi_write_count_we=1'b0;
                
                r_ns = LOOKUP;              
            end else begin//如果没有发来请求，则保持原状态
                cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                cache_wtype = 2'b00;//不发生写

                search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                search_buffer_we = 1'b0;//缓存cache查找出的数据
                cache_wway_buffer_we = 1'd0;
                
                addr_ok = 1'b0;
                data_ok = 1'b0;
             
                
                wr_req = 1'b0;//向外部aix发出写请求                           
                miss_replace_way_we = 1'b0;
                
                rd_req = 1'b0; 
                axi_write_count_we=1'b0;
                
                r_ns = RIDLE;
            end
        end LOOKUP:begin          
            cache_wway_buffer_we = 1'b1;
            axi_write_count_we=1'b0;
            //命中
            if(way0_cache_hit|way1_cache_hit  )begin
                wr_req = 1'b0;//向外部aix发出写请求                                     
                rd_req = 1'b0;
                //读请求命中
                if(~cache_search_op)begin
                    cache_wtype = 2'b00;//不发生写               
                    if(cache_re)begin//有新的读请求
                        cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求
      
                        search_addr_buffer_we = 1'b1;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b1;//缓存cache查找出的数据
                        
                        addr_ok = 1'b1;
                        data_ok = 1'b1;
                        
                        miss_replace_way_we = 1'b0;
         
                        r_ns = LOOKUP;
                        
                    end else if(cache_we)begin//有新的写请求
                        cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求
                        
                        search_addr_buffer_we = 1'b1;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b1;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b1;//缓存cache查找出的数据
                        
                        addr_ok = 1'b1;
                        data_ok = 1'b1;
                        miss_replace_way_we = 1'b0;
                    
                        r_ns = LOOKUP;                   
                    end else begin //没有新请求
                        cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                        
                        search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b0;//缓存cache查找出的数据
                        
                        addr_ok = 1'b0;
                        data_ok = 1'b1;
                        miss_replace_way_we = 1'b0;
           
                        r_ns = RIDLE;
                    
                    end
                end else begin//写请求命中
                    if(cache_re)begin//有新的读请求（不接受当前有读请求，因为写请求的数据还未写入）
                        cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                        
                        search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b0;//缓存cache查找出的数据
                        
                        addr_ok = 1'b0;
                        data_ok = 1'b1;
                        miss_replace_way_we = 1'b0;
     
                        r_ns = WRITE;
                    
                    
                    end else if(cache_we)begin//有新的写请求（也不接收因为cache缓存区只能缓存一次，上一次的写还没有完成）
                        cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                        
                        search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b0;//缓存cache查找出的数据
                        
                        addr_ok = 1'b0;
                        data_ok = 1'b1;
                        miss_replace_way_we = 1'b0;
           
                        r_ns = WRITE;
                    end else begin //没有新请求
                        cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                       
                        search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                        cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                        search_buffer_we = 1'b0;//缓存cache查找出的数据
                        
                        addr_ok = 1'b0;
                        data_ok = 1'b1;
                        miss_replace_way_we = 1'b0;
                      
                        r_ns = WRITE;
                    end
                
                end
            end else if(~way0_cache_hit|~way1_cache_hit)begin //没有命中,(包含读命中和写命中都没命中)
            
                cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求
                cache_wtype = 2'b00;//不发生写
                
                search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                search_buffer_we = 1'b0;//缓存cache查找出的数据
                
                addr_ok = 1'b0;
                if(cache_search_op)begin//如果是写没有命中，则直接放行
                    data_ok = 1'b1;
                end else begin
                    data_ok = 1'b0;
                end
                
                wr_req = 1'b0;//向外部aix发出写请求                               
                
                rd_req = 1'b0;
                miss_replace_way_we = 1'b1;
                
                r_ns = MISS;
            end
            
        end WRITE:begin//往cache内写数据
            
            cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求                 
            cache_wtype = 2'b01;//不发生写                                                                             
                                                                               
            search_addr_buffer_we = 1'b0;//将查找地址进行缓存                           
            cache_wdata_buffer_we = 1'b0;//将写数据进行缓存                            
            search_buffer_we = 1'b1;//缓存cache查找出的数据                            
            cache_wway_buffer_we = 1'd0;                                       
                                                                               
            addr_ok = 1'b0;//返回地址ok，表示请求已经接收啦                                  
            data_ok = 1'b0;                                                    
                                                                               
                                                                               
            wr_req = 1'b0;//向外部aix发出写请求                                        
                            
                                                                               
            rd_req = 1'b0;                                                     
            axi_write_count_we=1'b0;  
            miss_replace_way_we = 1'b0;                                         
                                                                               
            r_ns = RIDLE;                                                          
        
        end MISS:begin//读出要被替换的数据，等待外部允许接收写请求（替换的index和way是有随机产生的）
            axi_write_count_we=1'b0;
            cache_wway_buffer_we = 1'b0;
            if(wr_rdy)begin
                cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求
                cache_wtype = 2'b00;//不发生写

                
                               
                search_addr_buffer_we = 1'b0;//将查找地址进行缓存
                cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存
                search_buffer_we = 1'b1;//缓存cache查找出的数据
                
                addr_ok = 1'b0;
                data_ok = 1'b0;
                
                wr_req = 1'b0;//向外部aix发出写请求                            
       
                
                rd_req = 1'b0;
                miss_replace_way_we = 1'b0;
            
                r_ns = WRITEBACK;
            end else begin
                cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求                   
                cache_wtype = 2'b00;//不发生写                                           
                                                                             
                search_addr_buffer_we = 1'b0;//将查找地址进行缓存                             
                cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存                   
                search_buffer_we = 1'b0;//缓存cache查找出的数据                              
                                                                                     
                addr_ok = 1'b0;                                                      
                data_ok = 1'b0; 
                
                wr_req = 1'b0;//向外部aix发出写请求                            

                
                rd_req = 1'b0; 
                miss_replace_way_we = 1'b0;                                                   
               
                r_ns = MISS;
            end
        end WRITEBACK:begin//将要替换cache行数据发到axi中（如果写回数据是脏数据则在本状态进行写回，如果非脏数据本状态不进行写会踩在）
            cache_wway_buffer_we = 1'b0;
            cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求                   
            cache_wtype = 2'b00;//不发生写                                           
 
            search_addr_buffer_we = 1'b0;//将查找地址进行缓存                             
            cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存                   
            search_buffer_we = 1'b0;//缓存cache查找出的数据                              
        
            addr_ok = 1'b0;                                                      
            data_ok = 1'b0;
            
            rd_req = 1'b0; 
            axi_write_count_we=1'b0;
            miss_replace_way_we = 1'b0;
            if(miss_replace_way)begin
                 if(search_buffer[`Way1DLocation])begin
                    wr_req = 1'b1;
                 end else begin
                     wr_req = 1'b0;
                 end
            end else begin
                 if(search_buffer[`Way0DLocation])begin
                    wr_req = 1'b1;
                 end else begin
                     wr_req = 1'b0;
                 end
                
            end
                          
            r_ns = REPLACE;//一个时钟周期必定完成，所以直接跳转到下一个状态                               
            
                                       
                      
        end REPLACE :begin//将读请求发给axi，直到axi接收到数据，就跳转到下一个状态
            cache_wway_buffer_we = 1'b0;
            cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求             
            cache_wtype = 2'b00;//不发生写                                     
                                           
            miss_replace_way_we = 1'b0;                                   
                                                                           
            search_addr_buffer_we = 1'b0;//将查找地址进行缓存                       
            cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存             
            search_buffer_we = 1'b0;//缓存cache查找出的数据                        
                                                                           
            addr_ok = 1'b0;                                                
            data_ok = 1'b0;                                                
                                                                           
            wr_req = 1'b0;//发出写请求                                          
   
            rd_req = 1'b1;//读请求
            axi_write_count_we=1'b0;
            if( rd_rdy)begin
                r_ns = REFILL;
            end else begin
                r_ns = REPLACE;
            end
        end REFILL:begin//准备接收axi读出数据
                    
            cache_wway_buffer_we = 1'b0;     
                                            
            miss_replace_way_we = 1'b0;                                 
                                                                           
            search_addr_buffer_we = 1'b0;//将查找地址进行缓存                       
            cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存             
            search_buffer_we = 1'b0;//缓存cache查找出的数据         
            
            wr_req = 1'b0;//发出写请求                                          
            rd_req = 1'b0;//读请求                   
                                                                           
            addr_ok = 1'b0;                 
        
            if(ret_last & ret_valid)begin//如果当前数据是最后一个数据，则将当前数据和历史数据拼接，一同写入到cache中
                cache_en = 1'b1;//有cache读请求则cache使能，即要对cache进行读写请求   
                cache_wtype = 2'b10;//进行全写       
                axi_write_count_we=1'b1;                  
                data_ok = 1'b0;                                                
                                                                                
                r_ns = RIDLE;
            end else  if (ret_valid)begin //查找，返回会数据有没有待查在的数据有则返回data_ok
                cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求   
                cache_wtype = 2'b00;//不发生写  
                axi_write_count_we = 1'b1;    
                r_ns = REFILL;
                if(axi_write_count == search_addr_buffer[3:2] && !cache_search_op) begin//如果是读指令的话，则返回data_ok 
                    data_ok = 1'b1;
                end else begin
                    data_ok = 1'b0;
                end
            end else begin
                axi_write_count_we=1'b0;
                cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求   
                cache_wtype = 2'b00;//不发生写    
                data_ok = 1'b0;
                r_ns = REFILL;
            end     
        end default begin            
            cache_en = 1'b0;//有cache读请求则cache使能，即要对cache进行读写请求                   
            cache_wtype = 2'b00;//不发生写                                           
                                                  
            miss_replace_way_we = 1'b0;                                         
        
            search_addr_buffer_we = 1'b0;//将查找地址进行缓存                             
            cache_wdata_buffer_we = 1'b0;//将cpu要写入cache的数据进行缓存                   
            search_buffer_we = 1'b0;//缓存cache查找出的数据 
            cache_wway_buffer_we = 1'b0;                             
        
            addr_ok = 1'b0;                                                      
            data_ok = 1'b0;                                                      
            
            wr_req = 1'b0;//发出写请求                                    
            
            rd_req = 1'b0; 
            axi_write_count_we=1'b0;  
            r_ns = RIDLE;
        end
    endcase
 end
 
 
 //主状态转移
    always @(posedge clk)begin
       if(~resetn)begin
           r_cs <= RIDLE;
       end else begin
           r_cs <= r_ns;
       end
    end  

   
 //在write状态，写的数据是缓存cpu的，其他状态来自随机计数器
  assign cache_wway    = (r_cs ==WRITE) ? cache_wway_buffer  :miss_replace_way;
  assign cache_w_index =  search_addr_buffer[11:4] ;//更新读index是确定的，随机的是way 
    
 //cache查找表  
   cache_table cache_table_item(
       .clk       (clk)    ,
       .req_i     (cache_en)    ,
       .r_index_i (cache_rindex)    ,
       .r_data_o  (cache_rdata)    ,              //(20+1+1+128)*2=300 
                  
                  
       .way_i     (cache_wway)    ,//写的数据，写往第几路
       .w_index_i (cache_w_index)    ,//写地址
       .w_type_i  (cache_wtype)    ,//10为全写，01为部分写，00表示不写
       .offset_i  (search_addr_buffer[3:0])    ,//部分写的块内偏移地址                                             
       .wstrb_i   (cache_wstr_buffer)    ,//部分写的字节使能
       .w_data_i  (cache_wdata)     //发生部分写，则使用[31:0]位

    ); 
    
  //Cache读出数据
 assign rdata = (r_cs==REFILL) ? ret_data :
                way0_cache_hit ? (search_addr_buffer[3:2]==2'b00 ? search_buffer[`Way0Data0Location]:
                                  search_addr_buffer[3:2]==2'b01 ? search_buffer[`Way0Data1Location]:
                                  search_addr_buffer[3:2]==2'b10 ? search_buffer[`Way0Data2Location]:search_buffer[`Way0Data3Location]) :
                way0_cache_hit ? (search_addr_buffer[3:2]==2'b00 ? search_buffer[`Way1Data0Location]:
                                  search_addr_buffer[3:2]==2'b01 ? search_buffer[`Way1Data1Location]:
                                  search_addr_buffer[3:2]==2'b10 ? search_buffer[`Way1Data2Location]:search_buffer[`Way1Data3Location]) :32'd0;  
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
endmodule
