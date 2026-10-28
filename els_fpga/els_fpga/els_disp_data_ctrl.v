`include "els_disp_parameter.v"


//画面显示的驱动模块，向ddr请求数据，并产生图像使能信号与行，场同步信号：
module els_disp_data_ctrl 
(
    input clk,
    input reset_n,
    
    input [`RED_BITS+`GREEN_BITS+`BLUE_BITS-1:0] data_in,
    
    output reg data_req,                       //向ddr请求数据的信号
    output reg disp_de,                        //数据使能信号
    output disp_bl,                            //lcd显示屏背光信号（此工程不用）
    
    output reg [`RED_BITS-1:0] disp_data_red,
    output reg [`GREEN_BITS-1:0] disp_data_green,
    output reg [`BLUE_BITS-1:0] disp_data_blue,
    
    output reg hsync,                           //行同步信号
    output reg vsync,                           //场同步信号
    
    output disp_clk,                            //lcd显示屏输入时钟（此工程不用）
    
    output reg [12:0] pixel_x,
    output reg [12:0] pixel_y,
    
    output disp_sof                             //帧起始信号，表明一帧开始读取
    
    );
    
    
    assign disp_bl=reset_n;
    
    assign disp_clk=clk;
    
    
    //行计数器：
    reg [15:0] h_cnt;
    
    always @ (posedge clk)
    if(!reset_n) h_cnt<=0;
    else begin
        if(h_cnt==`H_Total_Time-1) h_cnt<=0;
        else h_cnt<=h_cnt+1;
        end
    
    
    //列计数器： 
    reg [15:0] v_cnt;
       
    always @ (posedge clk)
    if(!reset_n) v_cnt<=0;
    else if(h_cnt==`H_Total_Time-1) begin
        if(v_cnt==`V_Total_Time-1) v_cnt<=0;
        else v_cnt<=v_cnt+1;
        end
    
        //根据行计数器的计数产生行同步信号：    
        always @ (posedge clk)
        hsync<=(h_cnt>`H_Sync_Time - 1);
        
        //根据列计数器的计数产生场同步信号：
        always @ (posedge clk)
        vsync<=(v_cnt> `V_Sync_Time - 1);
    
    
    //根据行，列计数器的计数值产生数据使能信号： 
    reg disp_de_tpre;    //以_tpre结尾表示提前一个周期
        
    always @ (posedge clk)
    if(!reset_n) disp_de_tpre<=0;
    else if(h_cnt>=`H_Sync_Time+`H_Back_Porch+`H_Left_Border-1&&
            h_cnt<`H_Total_Time-`H_Front_Porch-`H_Right_Border-1&&
            v_cnt>=`V_Sync_Time+`V_Back_Porch+`V_Top_Border-1&&
            v_cnt<`V_Total_Time-`V_Front_Porch-`V_Bottom_Border-1)    disp_de_tpre<=1;
    else disp_de_tpre<=0;
    
    always @ (posedge clk)
    if(!reset_n) disp_de<=0;
    else disp_de<=disp_de_tpre;
    
    
    //data_req比disp_de_tpre提早一个周期生成，提前请求数据
    always @ (posedge clk)
    if(!reset_n) data_req<=0;
    else if(h_cnt>=`H_Sync_Time+`H_Back_Porch+`H_Left_Border-1-1&&
            h_cnt<`H_Total_Time-`H_Front_Porch-`H_Right_Border-1-1&&
            v_cnt>=`V_Sync_Time+`V_Back_Porch+`V_Top_Border-1&&
            v_cnt<`V_Total_Time-`V_Front_Porch-`V_Bottom_Border-1)      data_req<=1;
    else data_req<=0;
    
    
    //像素的行，列地址，显示此时数据是第几行第几列的数据：
    always @ (posedge clk)
    if(!reset_n) begin
        pixel_x<=0;
        pixel_y<=0;
        end
    else if(h_cnt>=`H_Sync_Time+`H_Back_Porch+`H_Left_Border-1-1&&
            h_cnt<`H_Total_Time-`H_Front_Porch-`H_Right_Border-1-1&&
            v_cnt>=`V_Sync_Time+`V_Back_Porch+`V_Top_Border-1&&
            v_cnt<`V_Total_Time-`V_Front_Porch-`V_Bottom_Border-1) 
            begin
                pixel_x<=h_cnt-(`H_Sync_Time+`H_Back_Porch+`H_Left_Border-1-1);
                pixel_y<=v_cnt-(`V_Sync_Time+`V_Back_Porch+`V_Top_Border-1);
                end
    else begin
        pixel_x<=0;
        pixel_y<=0;
        end
      
      
    //图像数据在经过data_req从ddr模块中读出后，再经一个周期输出   
    wire data_in_valid;    
        
    assign data_in_valid=disp_de_tpre;
        
    always @ (posedge clk)
    if(!reset_n) begin
        disp_data_red<=0;
        disp_data_green<=0;
        disp_data_blue<=0;
        end
        
    else if(data_in_valid) begin
        disp_data_red<=data_in[`RED_BITS+`GREEN_BITS+`BLUE_BITS-1:`GREEN_BITS+`BLUE_BITS];
        disp_data_green<=data_in[`GREEN_BITS+`BLUE_BITS-1:`BLUE_BITS];
        disp_data_blue<=data_in[`BLUE_BITS-1:0];
        end
    
    
    //对场同步信号做下降沿检测，以产生帧起始信号：
    reg vsync_sync0;
    
    wire neg_vsync;
        
    always @ (posedge clk)
    vsync_sync0<=vsync;
    
    assign neg_vsync=!vsync_sync0&&vsync;
    
    assign disp_sof=neg_vsync;
     
    
endmodule
