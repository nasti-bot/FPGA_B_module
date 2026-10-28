`timescale 1ns / 1ps

module els_DVP_capture_16bit (
    input pclk,
    input reset_n,
    
    input vsync,                //摄像头输入的场同步信号
    input href,                 //摄像头输入的行有效信号
    
    input [7:0] data_in,        //摄像头输入的8位数据
    
    output reg [15:0] data_out, //打包后输出的数据
    output reg data_valid       //数据有效标志信号
    
    );
    
    
    ///////////////
    //////////////
    //为保证输入信号的稳定，对其进行打两拍：
    
    reg sync0_vsync,sync1_vsync,
         sync0_href,sync1_href;
    reg [7:0] sync0_data_in,sync1_data_in;
    
    always @ (posedge pclk)
    begin
        sync0_vsync<=vsync;           //前面带sync0_表示是打一拍后的信号
        sync1_vsync<=sync0_vsync;     //前面带sync1_表示是打两拍后的信号
        
        sync0_href<=href;
        sync1_href<=sync0_href;
        
        sync0_data_in<=data_in;
        sync1_data_in<=sync0_data_in;
        end
    
    
  /////////////////
  ////////////////
  //为保证画面稳定，直接舍弃前5帧的图像数据：
    
    
        //检测行有效信号的下降沿：  
        wire neg_href;
        reg href_last;
          
        always @ (posedge pclk)
        href_last<=sync1_href;
        
        assign neg_href=!sync1_href&&href_last;
        
        
        //检测场同步信号的上升沿：
        wire pos_vsync;
        reg vsync_last;
        
        always @ (posedge pclk)
        vsync_last<=sync1_vsync;
        
        assign pos_vsync=sync1_vsync&&!vsync_last;
    
    
    //帧数计数器，显示目前是第几帧画面：
    reg [4:0] frame_cnt;
    reg dump_frame;
    
    always @ (posedge pclk)
    if(!reset_n) frame_cnt<=0;
    else if(pos_vsync) begin
        if(frame_cnt>=5) frame_cnt<=5;  //当到达第5帧时停止计数
        else frame_cnt<=frame_cnt+1;
        end
        
        
    //产生已经计好前5帧的标志：
    always @ (posedge pclk)
    if(!reset_n) dump_frame<=0;
    else if(frame_cnt>=5) dump_frame<=1;    //已经产生了5帧的数据，后面可以正常输出了
    else dump_frame<=0;                     //前5帧时标志信号为0
    
    
    //data_cnt计数来显示此时是第几个输入数据：
    
    reg [29:0] data_cnt;
    
    always @ (posedge pclk)
    if(!reset_n) data_cnt<=0;
    else if(sync1_href) begin
        data_cnt<=data_cnt+1;
        end
    else data_cnt<=0;
    
    //对输入数据进行打包，每相邻两个字节为一组：
    always @ (posedge pclk)
    if(!reset_n) data_out<=0;
    else if(sync1_href)begin
        if(!data_cnt[0]) data_out[15:8]<=sync1_data_in;     //先输入的是数据的高8位
        else if(data_cnt[0]) data_out[7:0]<=sync1_data_in;
        end
    else data_out<=0;
    
    //data_valid的产生：保证其能和相应数据对齐
    reg r_data_valid;
    
    always @ (posedge pclk)
    if(!reset_n) r_data_valid<=0;
    else if(!data_cnt[0]&&sync1_href) r_data_valid<=1; //预产生data_valid
    else r_data_valid<=0;
    
    always @ (posedge pclk)
    data_valid<=dump_frame&&r_data_valid;       //标志信号拉高后data_valid才正常输出
      
    
endmodule