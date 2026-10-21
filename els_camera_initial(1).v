`timescale 1ns / 1ps

module els_camera_initial #(
    parameter DATA_WIDTH=8,
    parameter ADDR_WIDTH=16,
    parameter OV_IMAGE_WIDTH=800,
    parameter OV_IMAGE_HEIGHT=480
) 
(
    input clk,
    input reset_n,
    
    output reg init_done,
    output i2c_sclk,
    
    inout i2c_sdata
    );
     
    localparam LUT_SIZE=256;
    
    reg [23:0] delay_cnt;
    reg [31:0] i2c_delay_cnt_max;
    reg [15:0] cnt;
    reg wr_req;
    reg wr_go;
    reg wr_req_tpre;
    
    wire [23:0] lut;
    wire rw_done;
    wire ack; 
    wire [DATA_WIDTH-1:0] wr_data;
    wire [ADDR_WIDTH-1:0] addr;
    wire addr_mode;
       
    always @ (posedge clk)
    if(!reset_n) delay_cnt<=0;
    else if(delay_cnt>=24'h100800) delay_cnt<=24'h100800;
    else delay_cnt<=delay_cnt+1;
    
    always @ (posedge clk)
    if(!reset_n) wr_go<=0;
    else if(delay_cnt==24'h100800-1) wr_go<=1;
    else wr_go<=0; 
    
    always @ (posedge clk)
    if(!reset_n)cnt<=0;
    else if(wr_go) cnt<=0;
    else if(cnt<LUT_SIZE)begin
        if(rw_done&&!ack)
            cnt<=cnt+1;
        end
    else cnt<=0;
        
    always @ (posedge clk)
    if(!reset_n) init_done<=0;
    else if(wr_go) init_done<=0;
    else if(cnt==LUT_SIZE) init_done<=1;
        
    always @ (posedge clk)
    if(!reset_n) wr_req_tpre<=0;
    else if(wr_go) wr_req_tpre<=1;
    else if(rw_done&&cnt<LUT_SIZE-1) wr_req_tpre<=1;
    else wr_req_tpre<=0;
    
    always @ (posedge clk)
    wr_req<=wr_req_tpre;
    
    always @ (posedge clk)
    if(!reset_n) i2c_delay_cnt_max<=0;
    else if(rw_done) begin
        if(cnt==0) i2c_delay_cnt_max<=32'h60000;
        else i2c_delay_cnt_max<=0;
        end
        
    assign wr_data=lut[7:0];
    
    assign addr=lut[23:8];
    
    assign addr_mode=(ADDR_WIDTH==16)?1'b1:1'b0;
    
    ov5640_initial_table #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .IMAGE_WIDTH(OV_IMAGE_WIDTH),
      .IMAGE_HEIGHT(OV_IMAGE_HEIGHT)
    )
    u0 (
    .clk(clk),
    .addr(cnt),
    .q(lut)
    );
    
    els_i2c_ctrl i2c_ctrl_inst (
    .clk(clk),
    .reset_n(reset_n),
    .device_id(8'h78),
    .wr_req(wr_req),
    .rd_req(1'b0),
    .wr_data(wr_data),
    .addr(addr),
    .addr_mode(1'b1),
    .i2c_sclk(i2c_sclk),
    .ack(ack),
    .rd_data(),
    .rw_done_post(rw_done),
    .i2c_delay_cnt_max(i2c_delay_cnt_max),
    .i2c_sdata(i2c_sdata)
    );
    
endmodule

