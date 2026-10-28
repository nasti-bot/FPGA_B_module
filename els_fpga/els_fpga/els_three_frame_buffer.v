`timescale 1ns / 1ps


//对ddr数据进行三帧缓存的模块：
module els_three_frame_buffer #(
    parameter FRAME_A_ADDR_BEGIN=0, //画面A的基地址
    parameter FRAME_B_ADDR_BEGIN=0, //画面B的基地址
    parameter FRAME_C_ADDR_BEGIN=0, //画面C的基地址
    
    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480
    
)
(

    input clk,
    input reset_n,
    
    input one_frame_wr_done,        //输入ddr读/写一帧完成的标志信号
    input one_frame_rd_done,
    
    output reg [30:0] frame_wr_addr_begin,  //输出下一帧画面数据存储的起始与终止地址
    output reg [30:0] frame_rd_addr_begin,
    output reg [30:0] frame_wr_addr_end,
    output reg [30:0] frame_rd_addr_end,
    
    output reg [3:0] axi_id,        //AXI地址的ID
    
    output reg axi_wr_en,           //AXI写使能
    output reg axi_rd_en            //AXI读使能
    
    );
    
    
  ////////////////////
  ////////////////////
  //使用三段式状态机，从接收到读写一帧完成标志到输出新地址需经过两个时钟周期：
  
    localparam S_IDLE=4'b1,       //表示此画面空闲，可以写
               S_WRITING=4'b10,   //表示此画面正在被写
               S_READING=4'b100,  //表示此画面正在被读
               S_READY=4'b1000;   //表示此画面已经被写好，可以读
               
        //画面A,B,C的状态与次态：          
        reg [3:0] A_state,B_state,C_state;           
        reg [3:0] A_next_state,B_next_state,C_next_state;
    
    always @ (posedge clk)
    if(!reset_n) begin
        A_state<=S_IDLE;
        B_state<=S_IDLE;
        C_state<=S_IDLE;
        end
    else begin
        A_state<=A_next_state;
        B_state<=B_next_state;
        C_state<=C_next_state;
        end
    
    
    //状态转换：
        //若写一帧完成，优先写当前空闲的帧；若无空闲帧，就写当前已被写好的帧，用新帧覆盖旧帧。
        //若读一帧完成，优先读当前已写好的帧；若无，就继续读当前帧，重复读同一帧直至有新帧被写完。
            
    always @ (*)
    begin
    
        case({A_state,B_state,C_state})
            
        //前两个状态里，因为还没有画面被写完过，先写完A画面
        {S_IDLE,S_IDLE,S_IDLE}:begin
        
                               {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_IDLE,S_IDLE};
                               
                               end
                               
        {S_WRITING,S_IDLE,S_IDLE}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_WRITING,S_IDLE};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_IDLE,S_IDLE};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end
    
        {S_READING,S_WRITING,S_IDLE}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_READY,S_WRITING};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_WRITING,S_IDLE};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end
                               
        {S_READING,S_READY,S_WRITING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_WRITING,S_READY};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_IDLE,S_READING,S_WRITING};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end
                               
        {S_IDLE,S_READING,S_WRITING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READING,S_READY};//
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_IDLE,S_READING,S_WRITING};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end
                               
        {S_READING,S_WRITING,S_READY}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_READY,S_WRITING};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_IDLE,S_WRITING,S_READING};//
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end                              
                               
        {S_WRITING,S_READING,S_READY}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READY,S_READING,S_WRITING};//
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_IDLE,S_READING};//
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end                               
                               
         {S_IDLE,S_WRITING,S_READING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READY,S_READING};//
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_IDLE,S_WRITING,S_READING};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end      
                               
        {S_READY,S_READING,S_WRITING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READING,S_READY};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_IDLE,S_WRITING};//
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end                              
                               
        {S_WRITING,S_IDLE,S_READING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READY,S_WRITING,S_READING};//
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_IDLE,S_READING};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end                              
                                                       
        {S_WRITING,S_READY,S_READING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READY,S_WRITING,S_READING};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READING,S_IDLE};//
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end     
                               
        {S_READING,S_IDLE,S_WRITING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_WRITING,S_READY};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_IDLE,S_WRITING};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end     
                               
        {S_READY,S_WRITING,S_READING}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READY,S_READING};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_READING,S_WRITING,S_IDLE};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end   
                               
        {S_WRITING,S_READING,S_IDLE}:begin
        
                               if(one_frame_wr_done) {A_next_state,B_next_state,C_next_state}<={S_READY,S_READING,S_WRITING};
                               
                               else if(one_frame_rd_done) {A_next_state,B_next_state,C_next_state}<={S_WRITING,S_READING,S_IDLE};
                               
                               else {A_next_state,B_next_state,C_next_state}<={A_state,B_state,C_state};
                               
                               end                 
    
        default:;
        endcase
        
        end
    
    

   //根据当前状态输出地址：
        
    always @ (posedge clk)
    if(!reset_n) begin
        frame_wr_addr_begin<=0;
        frame_rd_addr_begin<=0;
        
        axi_wr_en<=1;
        axi_rd_en<=0;
        
        end
    else begin
    
        if({A_state,B_state,C_state}=={S_WRITING,S_IDLE,S_IDLE}||{A_state,B_state,C_state}=={S_IDLE,S_IDLE,S_IDLE}) begin   //因为前两个状态还没有画面被写完，因此先不开始读
            frame_wr_addr_begin<=FRAME_A_ADDR_BEGIN;
            end
        
        else begin
        
            axi_rd_en<=1;                                                         //已有画面被写完，开始读
        
            if(A_state==S_WRITING) frame_wr_addr_begin<=FRAME_A_ADDR_BEGIN;
            else if(A_state==S_READING) frame_rd_addr_begin<=FRAME_A_ADDR_BEGIN;
            
            if(B_state==S_WRITING) frame_wr_addr_begin<=FRAME_B_ADDR_BEGIN;
            else if(B_state==S_READING) frame_rd_addr_begin<=FRAME_B_ADDR_BEGIN;
            
            if(C_state==S_WRITING) frame_wr_addr_begin<=FRAME_C_ADDR_BEGIN;
            else if(C_state==S_READING) frame_rd_addr_begin<=FRAME_C_ADDR_BEGIN;
            end
               
    end
    
    always @ (*)
    begin
        frame_wr_addr_end<=frame_wr_addr_begin+IMAGE_WIDTH*IMAGE_HEIGHT*2;      //终止地址刚好比基地址多一帧画面数据对应的地址数
        frame_rd_addr_end<=frame_rd_addr_begin+IMAGE_WIDTH*IMAGE_HEIGHT*2;
        
        axi_id<=0;
        end
    
endmodule
