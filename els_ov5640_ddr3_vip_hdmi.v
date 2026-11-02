`timescale 1ns / 1ps

module els_OV5640_ddr3_vip_hdmi #(
    parameter IMAGE_WIDTH=800,    //所用分辨率为800*480，显示类型为RGB565
    parameter IMAGE_HEIGHT=480
)
(

    input pll_clkin12m,		//systemPLL的输入时钟（12M）
    input pll_clkin24m,		//xclkPLL的输入时钟（24M）
    
    input clk_168m,


    //system:
    
    input clk_96m,	         //AXI控制模块所用时钟
	
	input clk_48m,  		 //摄像头初始化模块所用时钟
    
    input clk_36m,	         //HDMI一倍时钟
    input clk_72m,	         //HDMI两倍时钟
    input clk_180m,	         //HDMI五倍时钟
    
    input clk_24m, 		     //提供给ov5640摄像头的24M的xclk
    
	
    input locked1,		     //systemPLL的locked信号
    input locked2,			 //hdmiPLL的locked信号
    input locked3,			 //xclkPLL的locked信号
    
    output hdmi_pll_resetn,  //hdmiPLL的复位信号
    
	
    //ov:
    input ov_pclk,		 //摄像头输出的pclk
    
    input ov_vsync,		 //摄像头输入图像数据的场同步信号（画面正常输入时为高）
    input ov_href,		 //摄像头输入图像数据的行有效信号（高电平有效）
    
    input [7:0] ov_data_in,  //摄像头输出的8位图像数据
    
		//iic:
		output cmos_sclk,		 //摄像头初始化所用IIC协议的sclk
		input cmos_sdata_i,		 //摄像头初始化所用IIC协议的sdat(inout)
		output cmos_sdata_o,
		output cmos_sdata_oe,
    
    //ddr:
        
        //ddr_rst:
        output ddr_ctrl_rstn,			//ddr复位核的复位信号
        output ddr_ctrl_cfg_seq_rst,
        output ddr_ctrl_cfg_seq_start,
            
        //A:
        input axi_aready_0,
        
        output [7:0] axi_aid_0,
        output [31:0] axi_aaddr_0,
        output [7:0] axi_alen_0,
        output [2:0] axi_asize_0,
        output [1:0] axi_aburst_0,
        output [1:0] axi_alock_0,
        output axi_avalid_0,
        output axi_atype_0,
        
        
        //W:
        input axi_wready_0,
        
        output [7:0] axi_wid_0,
        output [127:0] axi_wdata_0,
        output [15:0] axi_wstrb_0,
        output axi_wlast_0,
        output axi_wvalid_0,
        
               
        //B:
        input [7:0] axi_bid_0,
        input axi_bvalid_0,
        
        output axi_bready_0,
        
        
        //R:
        input [7:0] axi_rid_0,
        input [127:0] axi_rdata_0,
        input axi_rlast_0,
        input axi_rvalid_0,
        input [1:0] axi_rresp_0,
        
        output axi_rready_0,
    
  
    //hdmi:
    output [4:0] hdmi_tx_c_o,
    output [4:0] hdmi_tx_0_o,
    output [4:0] hdmi_tx_1_o,
    output [4:0] hdmi_tx_2_o,
	
	
	//KEY:
	input key_level,		  	  //改变边缘检测的阈值
	input key_mode,          	  //选择此时进行边缘检测还是图形识别

    
    //LED:
    output [2:0] led
    
 
);

    wire  resetn_DDRrst_ctrler,			//ddr复位核的复位信号
          resetn_camera_init;       	//摄像头初始化模块的复位信号
    wire  reset_n;						//其余模块的复位信号

	
	assign hdmi_pll_resetn = locked1;	//hdmiPLL的复位信号
	
    wire locked = locked1 && locked2 && locked3;
	wire ddr3_init_done;
	wire camera_init_done;
	
	
	//led灯显示进程：（低电平亮灯）
    assign led[2]=!locked;     			//全部PLL形成成功后亮灯
    assign led[1]=!ddr3_init_done;  	//ddr复位成功后亮灯
    assign led[0]=!camera_init_done; 	//摄像头初始化成功后亮灯

     


  //////////////////
  //////////////////
  //各模块所用时钟：
    
    wire  axi_clk,			//axi_ctrl模块所用时钟
		  cameinit_clk,     //摄像头初始化模块所用时钟
          hdmi_clk,			//hdmi一倍时钟
          hdmi_clkx2,		//hdmi两倍时钟
          hdmi_clkx5;		//hdmi五倍时钟
    
    
    assign axi_clk=clk_96m;   
	
	assign cameinit_clk=clk_48m;
    
    assign hdmi_clk=clk_36m;      
    assign hdmi_clkx2=clk_72m;   
    assign hdmi_clkx5=clk_180m;    
    
    

 /////////
 ////////
 //ddr复位核：
 
 
	assign resetn_DDRrst_ctrler=locked;			  //PLL全部形成成功后开始ddr复位
 
	 etx_ddr3_reset_controller U0_DDR_Reset
	( 
		.ddr_rstn_i(resetn_DDRrst_ctrler),
		.clk(axi_clk),
		
		.ddr_rstn(ddr_ctrl_rstn),
		.ddr_cfg_seq_rst(ddr_ctrl_cfg_seq_rst),
		.ddr_cfg_seq_start(ddr_ctrl_cfg_seq_start),
		.ddr_init_done(ddr3_init_done)
	);   
    
    
    
  ///////////
  ///////////
  //摄像头初始化模块：
  
  
	assign resetn_camera_init=resetn_DDRrst_ctrler && ddr3_init_done;	//ddr复位成功后开始摄像头初始化
    
   els_camera_init #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(16),
        .OV_IMAGE_WIDTH(IMAGE_WIDTH),
        .OV_IMAGE_HEIGHT(IMAGE_HEIGHT)
    )  
    (
    .clk(cameinit_clk),
    .reset_n(resetn_camera_init),
    
    .init_done(camera_init_done),
    
    .i2c_sclk(cmos_sclk),      
    .i2c_sdata_i(cmos_sdata_i),
    .i2c_sdata_o(cmos_sdata_o),
    .i2c_sdata_oe(cmos_sdata_oe)
    
    );
    
    
    assign reset_n=resetn_camera_init && camera_init_done;          //摄像头初始化成功后其余模块开始工作
	
  //////////////  
  /////////////
  //收集并打包摄像头输出的数据，将其写入ddr:
  
    wire [15:0] ov_data_out;					//模块打包好的16位RGB图像数据
    wire ov_data_valid;							//RGB图像数据的有效信号
    
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
  //axi控制模块，控制ddr的读和写：(只使用target0)
    
    wire [15:0] ddr_data_out_0;		//从ddr中读出的数据
    wire [15:0] ddr_data_in_0;		//待写入ddr的数据
    
    wire ddr_data_in_valid_0;
    
    wire disp_sof_0;					//开始读新一帧的起始信号
    wire data_req_0;					//读数据请求
    
    wire axi_wr_en_0,					//axi读写使能
         axi_rd_en_0;
    
    wire one_frame_wr_done_0,   		//一帧图像写完的标志信号
         one_frame_rd_done_0; 		//一帧图像读完的标志信号
    
    wire [7:0] axi_id_0;				 //axi地址id
    wire [31:0] axi_wr_addr_begin_0,	 //axi读写基地址与末地址
                axi_wr_addr_end_0,
                axi_rd_addr_begin_0,
                axi_rd_addr_end_0;
                
    assign ddr_data_in_0=ov_data_out;
    assign ddr_data_in_valid_0=ov_data_valid;
    
    
    els_axi_ctrl #(

        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        
        .FIFO_DW(16),                  //ddr读写的数据的位宽
        
        .AXI_DATA_WIDTH(128),          //axi传输时的数据位宽
        .AXI_ADDR_WIDTH(32),
        .AXI_ID_WIDTH(8),
    
        .AXI_BURST_LEN(7),			   //AXI的实际突发长度为：7+1=8
        .FIFO_TO_AXI_DATA_DEPTH(64)    //读写fifo的axi方向的数据深度
		
    )  target0
    (
        .clk(axi_clk),
        .reset_n(reset_n),
          
        .axi_wr_en(axi_wr_en_0),
        .axi_rd_en(axi_rd_en_0),
        
        
        //wr_fifo:
        .wrfifo_wr_clk(ov_pclk),
        .wrfifo_clr(~reset_n),
        .wrfifo_wr_en(ddr_data_in_valid_0),
        
        .wrfifo_wr_data(ddr_data_in_0),
        
        
        //rd_fifo:
        .rdfifo_rd_clk(hdmi_clk),
        .rdfifo_clr(disp_sof_0),
        .rdfifo_rd_en(data_req_0),
        
        .rdfifo_rd_data(ddr_data_out_0),
        
        
        //AXI_addr:
        .axi_wr_addr_begin(axi_wr_addr_begin_0),
        .axi_wr_addr_end(axi_wr_addr_end_0),
        .axi_rd_addr_begin(axi_rd_addr_begin_0),
        .axi_rd_addr_end(axi_rd_addr_end_0),
        
        .axi_id(axi_id_0),
        
        
        //done:
        .one_frame_wr_done(one_frame_wr_done_0),
        .one_frame_rd_done(one_frame_rd_done_0),
        
        
        //AXI:
            
            //A:
            .axi_aready(axi_aready_0),
            
            .axi_aid(axi_aid_0),
            .axi_aaddr(axi_aaddr_0),
            .axi_alen(axi_alen_0),
            .axi_asize(axi_asize_0),
            .axi_aburst(axi_aburst_0),
            .axi_alock(axi_alock_0),
            .axi_avalid(axi_avalid_0),
            .axi_atype(axi_atype_0),
            
            
            //W:
            .axi_wready(axi_wready_0),
            
            .axi_wid(axi_wid_0),
            .axi_wdata(axi_wdata_0),
            .axi_wstrb(axi_wstrb_0),
            .axi_wlast(axi_wlast_0),
            .axi_wvalid(axi_wvalid_0),
            
                   
            //B:
            .axi_bid(axi_bid_0),
            .axi_bvalid(axi_bvalid_0),
            
            .axi_bready(axi_bready_0),
            
            
            //R:
            .axi_rid(axi_rid_0),
            .axi_rdata(axi_rdata_0),
            .axi_rlast(axi_rlast_0),
            .axi_rvalid(axi_rvalid_0),
            .axi_rresp(axi_rresp_0),
            
            .axi_rready(axi_rready_0)
            
             
             
    );
      
     
   /////////////////////
   ////////////////////
   //三帧缓存状态机：
   
   els_three_frame_buffer #(
    .FRAME_A_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*0),  //画面A的基地址
    .FRAME_B_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*1),  //画面B的基地址
    .FRAME_C_ADDR_BEGIN(IMAGE_WIDTH*IMAGE_HEIGHT*2*2),  //画面C的基地址
    
    .IMAGE_WIDTH(IMAGE_WIDTH),                          
    .IMAGE_HEIGHT(IMAGE_HEIGHT)  
)
(
    .clk(axi_clk),
    .reset_n(reset_n),
    
    .one_frame_wr_done(one_frame_wr_done_0),
    .one_frame_rd_done(one_frame_rd_done_0),
    
    .frame_wr_addr_begin(axi_wr_addr_begin_0),
    .frame_rd_addr_begin(axi_rd_addr_begin_0),
    .frame_wr_addr_end(axi_wr_addr_end_0),
    .frame_rd_addr_end(axi_rd_addr_end_0),
    
    .axi_id(axi_id_0),
    
    .axi_wr_en(axi_wr_en_0),
    .axi_rd_en(axi_rd_en_0)
    
    );  
     
     
     
     
    /////////////////// 
    ////////////////////
    //读出ddr中的数据并产生行，场同步信号（lcd显示驱动模块）：
    
    wire raw_data_valid;                        //处理前的原始图像数据的有效信号
    
    wire [4:0] raw_data_red,
                raw_data_blue;
    wire [5:0] raw_data_green;
    wire [15:0] raw_data;                       //处理前的原始图像数据
    
    wire raw_data_hsync,raw_data_vsync;         //处理前的原始图像数据的行，场同步信号
    
    assign raw_data={raw_data_red,raw_data_green,raw_data_blue};
    

    els_disp_data_ctrl 
    (
    .clk(hdmi_clk),
    .reset_n(reset_n),
    
    .data_in(ddr_data_out_0),
    
    .data_req(data_req_0),
    .disp_de(raw_data_valid),
    
    .disp_bl(disp_bl),
    .disp_clk(disp_clk),
    
    .disp_data_red(raw_data_red),
    .disp_data_green(raw_data_green),
    .disp_data_blue(raw_data_blue),
    
    .hsync(raw_data_hsync),
    .vsync(raw_data_vsync), 
    
    .pixel_x(),
    .pixel_y(),
    
    .disp_sof(disp_sof_0)
    
    );
    

    
  
  ////////////////
  ////////////////
  //图像处理模块，将原始图像数据处理，进行边缘检测与简单识别：
		//Line A:边缘检测;
		//Line B:图形识别（矩形，圆形）
  
    wire [15:0] disp_data;                      //处理后的图像数据
    wire [4:0] disp_data_red,disp_data_blue;
    wire [5:0] disp_data_green;
    
    wire disp_data_valid;                       //处理后的图像数据的有效信号
    wire disp_data_hsync,disp_data_vsync;       //处理后的图像数据的行，场同步信号
    
    assign disp_data_red=disp_data[15:11];
    assign disp_data_green=disp_data[10:5];
    assign disp_data_blue=disp_data[4:0];
    
	
	els_vip_top #(
		.IMG_W(IMAGE_WIDTH),
		.IMG_H(IMAGE_HEIGHT),
		.LINE_W(1056),
		.MIN_AREA(300)    // LineB 最小填充面积（过滤噪点）
	)
	(
		.clk(hdmi_clk),
		.rst_n(reset_n),
		
		.rgb565_in(raw_data),      // 原始数据 RGB565
		.din_valid(raw_data_valid),
		.din_hsync(raw_data_hsync),
		.din_vsync(raw_data_vsync),
		
		.key_mode(key_mode),         // 低有效，按下切换 A/B
		.key_level(key_level),        // 低有效，按下循环调阈值档位（线A）
		.key_debug(1),             // 低有效，按下循环切换调试显示（0~4）
		
		.rgb565_out(disp_data),     // 叠加后的输出
		.dout_valid(disp_data_valid),
		.dout_hsync(disp_data_hsync),
		.dout_vsync(disp_data_vsync)
);

	
	
	
    
 /////////////
 ////////////
 //HDMI显示的驱动模块：
 
    wire [7:0] hdmi_red,hdmi_green,hdmi_blue;   //HDMI待显示数据
    
    wire hdmi_de;                               //HDMI待显示数据使能信号
    wire hdmi_hsync,hdmi_vsync;                 //HDMI待显示数据的行，场同步信号
    
	//
    assign hdmi_de=disp_data_valid;
    
    assign hdmi_hsync=disp_data_hsync;
    assign hdmi_vsync=disp_data_vsync;
    
    assign hdmi_red={disp_data_red,3'b0};
    assign hdmi_green={disp_data_green,2'b0}; 
    assign hdmi_blue={disp_data_blue,3'b0};
    
    els_hdmi_tx 
    (
    .pixel_clk(hdmi_clk),
    .pixel_clkx2(hdmi_clkx2),
    .pixel_clkx5(hdmi_clkx5),
    .reset_n(reset_n),
    
    .din_blue(hdmi_blue),
    .din_green(hdmi_green),
    .din_red(hdmi_red),
	
    .hsync(hdmi_hsync),
    .vsync(hdmi_vsync),
    .de(hdmi_de),
    
    .hdmi_tx_c_o(hdmi_tx_c_o),
    .hdmi_tx_0_o(hdmi_tx_0_o),
    .hdmi_tx_1_o(hdmi_tx_1_o),
    .hdmi_tx_2_o(hdmi_tx_2_o)
    
    );
    


endmodule