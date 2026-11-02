`timescale 1ns / 1ps

module els_ov_ddr_hdmi #(
    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480
)
(
    //system:
    input clk,
    input reset_n_pre3,
    
    //ov:
    input ov_pclk,
    input ov_vsync,
    input ov_href,
    input [7:0] ov_data_in,
    
    output ov_xclk,
    output i2c_sclk,
    
    inout i2c_sdata,
    
    //ddr:
    output [14:0] ddr3_addr,
    output [2:0] ddr3_ba,
    output ddr3_cas_n,
    output [0:0] ddr3_ck_n,
    output [0:0] ddr3_ck_p,
    output [0:0] ddr3_cke,
    output ddr3_ras_n,
    output ddr3_reset_n,
    output ddr3_we_n,
    inout [15:0] ddr3_dq,
    inout [1:0] ddr3_dqs_n,
    inout [1:0]	ddr3_dqs_p,
    output [0:0] ddr3_cs_n,
    output [1:0] ddr3_dm,
    output [0:0] ddr3_odt,
     
    //hdmi:
    output hdmi_clk_p,
    output hdmi_clk_n,
    output [2:0] hdmi_data_p,
    output [2:0] hdmi_data_n,
    output hdmi_oe,
    
    //LED:
    output [2:0] led
    
    );
    
    wire reset_n_pre2,
          reset_n_pre1,
          reset_n;
    
    wire locked;
    wire camera_init_done;
    wire ddr3_init_done;
     
    assign led[2]=locked;            //显示pll是否成功产生锁相环
    assign led[1]=ddr3_init_done;    //显示ddr是否成功初始化  
    assign led[0]=camera_init_done;  //显示ov5640摄像头是否初始化成功
    
    assign reset_n_pre2=reset_n_pre3&&locked;           //pll成功产生锁相环时才能为1
    assign reset_n_pre1=reset_n_pre2&&ddr3_init_done;   //ddr成功初始化才能为1
    assign reset_n=reset_n_pre1&&camera_init_done;      //ov5640成功初始化才能为1
                                                        //即，只有当各模块都成功初始化后reset_n才能为1
    
    
 //////////////
 /////////////
 //PLL模块产生各个时钟：
    
    wire clk_50m,clk_40m,clk_200m,clk_24m;
    
    pll_clk 
    (
    .clk_out1(clk_50m),     //系统使用的总体时钟
    .clk_out2(clk_40m),     //读ddr数据的时钟
    .clk_out3(clk_200m),    //提供给ddr的mig的时钟，同时也是hdmi的五倍频率时钟
    .clk_out4(clk_24m),     //提供给ov5640摄像头的xclk

    .resetn(reset_n_pre3),
    .locked(locked), 
  
    .clk_in1(clk)
    ); 
    
    assign ov_xclk=clk_24m; //24M的时钟直接提供给ov5640摄像头
    
    
    
  ///////////
  ///////////
  //对ov5640摄像头进行初始化：
    
   els_camera_init #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(16),
        .OV_IMAGE_WIDTH(IMAGE_WIDTH),
        .OV_IMAGE_HEIGHT(IMAGE_HEIGHT)
    )  
    (
    .clk(clk_50m),
    .reset_n(reset_n_pre1),
    
    .init_done(camera_init_done),
    
    .i2c_sclk(i2c_sclk),        //使用IIC协议
    
    .i2c_sdata(i2c_sdata)
    );
    
    
    
  //////////////  
  /////////////
  //收集摄像头采集到的数据，打包完输出：
  
    wire [15:0] ov_data_out;
    wire ov_data_valid;
    
    els_DVP_capture_16bit 
    (
    .reset_n(reset_n),
    .pclk(ov_pclk),
    .vsync(ov_vsync),
    .href(ov_href),
    .data_in(ov_data_in),

    .data_out(ov_data_out),
    .data_valid(ov_data_valid)
    );
    
    
    
  //////////////
  /////////////
  //使用ddr进行数据读写的模块，使用AXI协议：
    
    wire [15:0] ddr_data_out;
    wire [15:0] ddr_data_in;
    
    wire ddr_data_in_valid;
    
    wire disp_sof;
    wire data_req;
    
    wire axi_wr_en,
         axi_rd_en;
    
    wire one_frame_wr_done,     //一帧数据写完的标志信号
         one_frame_rd_done;     //一帧数据读完的标志信号
         
    wire ddr_ui_clk;
    
    wire [3:0] axi_id;
    wire [30:0] axi_wr_addr_begin,
                axi_wr_addr_end,
                axi_rd_addr_begin,
                axi_rd_addr_end;
                
    assign ddr_data_in=ov_data_out;
    assign ddr_data_in_valid=ov_data_valid;
    
    els_ddr_ctrl_2ports #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .FIFO_DW(16),//FIFO_DW=FIFO_TO_OUT_DATA_WIDTH:即fifo向外的数据位宽
        .AXI_DATA_WIDTH(128),//实际上相当于fifo向内的数据位宽
        .AXI_ADDR_WIDTH(29),
        .AXI_ID_WIDTH(4),
//        .AXI_ID(0),
        .AXI_BURST_LEN(31),
        .FIFO_TO_AXI_DATA_DEPTH(64)//fifo向内的数据（地址）深度
    ) 
    (
    .ddr3_clk_200m(clk_200m),
    .ddr3_rst_n(reset_n_pre2),
    
    .axi_wr_en(axi_wr_en),
    .axi_rd_en(axi_rd_en),
    
    .wrfifo_clr(~reset_n),
    .wrfifo_clk(ov_pclk),
    .wrfifo_wr_en(ddr_data_in_valid),
    .wrfifo_din(ddr_data_in),
    
    .rdfifo_clr(disp_sof),
    .rdfifo_clk(clk_40m),
    .rdfifo_rd_en(data_req),
    
    .wrfifo_full(),
    .wrfifo_wr_cnt(),
    .rdfifo_dout(ddr_data_out),
    .rdfifo_empty(),
    .rdfifo_rd_cnt(),
    
    
    //ddr读写模块接收来自帧缓存状态机的读写基地址，作为新帧的起始，终止地址：
    
    .axi_wr_addr_begin(axi_wr_addr_begin),  
    .axi_wr_addr_end(axi_wr_addr_end),
    .axi_rd_addr_begin(axi_rd_addr_begin),
    .axi_rd_addr_end(axi_rd_addr_end),
    
    .axi_id(axi_id),
    
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_cke(ddr3_cke),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    
    .ddr3_init_done(ddr3_init_done),
    .ui_clk(ddr_ui_clk),
    
    .one_frame_wr_done(one_frame_wr_done),
    .one_frame_rd_done(one_frame_rd_done)
    
    );
      
     
   /////////////////////
   ////////////////////
   //使用三帧缓存对图像数据进行缓存，防止画面撕裂：
   
   els_three_frame_buffer #(
    .FRAME_A_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*0),  //A画面基地址
    .FRAME_B_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*1),  //B画面基地址
    .FRAME_C_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*2),  //C画面基地址
    
    .IMAGE_WIDTH(IMAGE_WIDTH),                          
    .IMAGE_HEIGHT(IMAGE_HEIGHT)  
)
(
    .clk(ddr_ui_clk),
    .reset_n(reset_n),
    
    .one_frame_wr_done(one_frame_wr_done),
    .one_frame_rd_done(one_frame_rd_done),
    
    .frame_wr_addr_begin(axi_wr_addr_begin),
    .frame_rd_addr_begin(axi_rd_addr_begin),
    .frame_wr_addr_end(axi_wr_addr_end),
    .frame_rd_addr_end(axi_rd_addr_end),
    
    .axi_id(axi_id),
    
    .axi_wr_en(axi_wr_en),
    .axi_rd_en(axi_rd_en)
    
    );  
     
     
     
     
    /////////////////// 
   ////////////////////
   //从ddr中读出数据，并产生行，场同步信号以及数据使能信号：
    
    wire raw_data_valid;                        //处理前原始图像数据有效信号
    
    wire [4:0] raw_data_red,raw_data_blue;
    wire [5:0] raw_data_green;
    wire [15:0] raw_data;                       //原始图像数据
    
    wire raw_data_hsync,raw_data_vsync;         //处理前的原始图像数据的行，场同步信号
    
    assign raw_data={raw_data_red,raw_data_green,raw_data_blue};
     
    els_disp_data_ctrl 
    (
    .clk(clk_40m),
    .reset_n(reset_n),
    
    .data_in(ddr_data_out),
    
    .data_req(data_req),
    .disp_de(raw_data_valid),
    .disp_bl(),
    .disp_data_red(raw_data_red),
    .disp_data_green(raw_data_green),
    .disp_data_blue(raw_data_blue),
    .hsync(raw_data_hsync),
    .vsync(raw_data_vsync),
    .disp_clk(),
    .pixel_x(),
    .pixel_y(),
    
    .disp_sof(disp_sof)
    
    );
    
  
  ////////////////
  ////////////////
  //对读出的原始数据进行图像处理，同时对data_valid,hsync,vsync延迟，与处理后数据对齐后输出：
  
    wire [15:0] disp_data;                  //处理后的数据
    wire [4:0] disp_data_red,disp_data_blue;
    wire [5:0] disp_data_green;
    
    wire disp_data_valid;                   //处理后的数据有效信号
    wire disp_data_hsync,disp_data_vsync;   //处理后的数据行，场同步信号
    
    assign disp_data_red=disp_data[15:11];
    assign disp_data_green=disp_data[10:5];
    assign disp_data_blue=disp_data[4:0];
    
    els_edge_pipeline #(
        .IMG_W(IMAGE_WIDTH),        // 一行宽
        .THRESHOLD(100),  // 边缘阈值
        .DELAY(35)       // 原图延迟拍数（与 edge_flag 对齐）
    )
    (
        .clk(clk_40m),
        .rst_n(reset_n),
        
        .rgb565_in(raw_data),   // 摄像头来的 16 位 RGB565
        
        .din_valid(raw_data_valid),           // 数据有效
        .din_hsync(raw_data_hsync),           // 行同步
        .din_vsync(raw_data_vsync),           // 帧同步
        
        .rgb565_out(disp_data),   // 输出像素
        
        .dout_valid(disp_data_valid),          // 输出有效（与 rgb565_out 同步）
        .dout_hsync(disp_data_hsync),          // 输出行同步
        .dout_vsync(disp_data_vsync)           // 输出帧同步
);
  
    
    
 /////////////
 ////////////
 //HDMI显示的驱动模块：
 
    wire [7:0] hdmi_red,hdmi_green,hdmi_blue;   //hdmi待显示的数据
    
    wire hdmi_de;                               //hdmi待显示数据的使能/有效信号
    wire hdmi_hsync,hdmi_vsync;                 //hdmi待显示数据的行，场同步信号
    
    assign hdmi_oe=reset_n;
    
    assign hdmi_de=raw_data_valid;
    
    assign hdmi_hsync=raw_data_hsync;
    assign hdmi_vsync=raw_data_vsync;
    
    assign hdmi_red={raw_data_red,3'b0};
    assign hdmi_green={raw_data_green,2'b0}; 
    assign hdmi_blue={raw_data_blue,3'b0};
    
    els_hdmi_ctrl 
    (
    .pixel_clk(clk_40m),
    .pixel_clkx5(clk_200m),
    .reset_n(reset_n),
    
    .din_blue(hdmi_blue),
    .din_green(hdmi_green),
    .din_red(hdmi_red),
    .hsync(hdmi_hsync),
    .vsync(hdmi_vsync),
    .de(hdmi_de),
    
    .tmds_clk_p(hdmi_clk_p),
    .tmds_clk_n(hdmi_clk_n),
    .tmds_data_p(hdmi_data_p),
    .tmds_data_n(hdmi_data_n)
    
    );
    
    
    
endmodule
