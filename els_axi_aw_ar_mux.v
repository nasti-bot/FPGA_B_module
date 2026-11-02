`timescale 1ns / 1ps


//AW, AR--->A。数据选择器：
module els_axi_aw_ar_mux #(
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4
)
(
    input clk,
    input reset_n,
    
    
    //aw:
    input [AXI_ADDR_WIDTH-1:0] axi_awaddr_i,
    input axi_awvalid_i,
    input [7:0] axi_awlen_i,
    input [AXI_ID_WIDTH-1:0] axi_awid_i,
    
    output reg axi_awready_o,
    
    
    //ar:
    input [AXI_ADDR_WIDTH-1:0] axi_araddr_i,
    input axi_arvalid_i,
    input [7:0] axi_arlen_i,
    input [AXI_ID_WIDTH-1:0] axi_arid_i,
    
    output reg axi_arready_o,
    
    
    //a:
    input axi_aready_i,
    
    output [AXI_ID_WIDTH-1:0] axi_aid_o,
    output [AXI_ADDR_WIDTH-1:0] axi_aaddr_o,
    output [7:0] axi_alen_o,
    output reg axi_atype_o,
    output reg axi_avalid_o

    );
    
    
  ////////////////////////////////////
  ///////////////////////////////////
  //使用三段式状态机来管理atype与读写相关信号:
  
    localparam S_RW_REQ_IDLE=3'b1,            //读写请求空闲态
               S_RW_REQ_BRIDGE=3'b10,         //读写请求联系态，等待握手成功
               S_RW_REQ_INC=3'b100;           //读写请求转换态，读请求->写请求，写请求->读请求
               
    reg [2:0] state,next_state;
    
    
    always @ (posedge clk)
    if(!reset_n) state<=S_RW_REQ_IDLE;
    else state<=next_state;
    
    
    //状态转换：
    always @ (*)
    case(state)
    
    S_RW_REQ_IDLE:if(axi_atype_o==0) begin                                  //若此时准备读：
                        if(axi_arvalid_i) next_state<=S_RW_REQ_BRIDGE;      //收到读地址有效信号后进入联系态
                        else next_state<=S_RW_REQ_INC;                     //否则转到转换态准备写
                        end
                        
                   else if(axi_atype_o==1) begin                            //若此时准备写：
                        if(axi_awvalid_i) next_state<=S_RW_REQ_BRIDGE;      //收到写地址有效信号后进入联系态
                        else next_state<=S_RW_REQ_INC;                     //否则转到转换态准备读
                        end
    
    
    S_RW_REQ_BRIDGE:if(axi_aready_i) next_state<=S_RW_REQ_INC;              //当处于联系态且从机准备好接收地址后，此时握手成功，进入转换态改变读写请求
                    else next_state<=S_RW_REQ_BRIDGE;                       //否则一直等从机准备好
    
    
    S_RW_REQ_INC:next_state<=S_RW_REQ_IDLE;                                 //一个周期后立刻回到空闲态
    
    
    default:next_state<=S_RW_REQ_IDLE;
    endcase
  
  
    //状态机输出：
    always @ (posedge clk)
    if(!reset_n) begin
        axi_awready_o<=0;
        axi_arready_o<=0;
        
        axi_atype_o<=0;
        
        axi_avalid_o<=0;

        end
        
    else begin
        
        
        //axi_awready_o:
        if(state==S_RW_REQ_BRIDGE && axi_aready_i && axi_atype_o==1) axi_awready_o<=1;  //当此时是写地址时，若接收到从机准备好的信号，就拉高awready告诉其他模块写地址完成了
        else axi_awready_o<=0;
        
        
        //axi_arready_o:
        if(state==S_RW_REQ_BRIDGE && axi_aready_i && axi_atype_o==0) axi_arready_o<=1;  //当此时是读地址时，若接收到从机准备好的信号，就拉高arready告诉其他模块写地址完成了
        else axi_arready_o<=0;
        
        
        //axi_atype_o:
        if(state==S_RW_REQ_INC) axi_atype_o<=~axi_atype_o;                              //每当到达转换态，改变读写
        
        
        //axi_avalid_o:
        if(state==S_RW_REQ_IDLE) begin                                                  //当处于空闲态，等待valid信号：
             if(axi_atype_o==1 && axi_awvalid_i) axi_avalid_o<=1;                                //若写操作时写地址有效，告诉从机地址有效了
             else if(axi_atype_o==0 && axi_arvalid_i) axi_avalid_o<=1;                          //若读操作时读地址有效，告诉从机地址有效了
             end
             
         else if(state==S_RW_REQ_BRIDGE && axi_aready_i) axi_avalid_o<=0;               //当握手成功后，从机已经成功接收到地址后，拉低avalid，完成一次地址传输
         
         else axi_avalid_o<=axi_avalid_o;

    end
    
    
        //其余相关输出：
        assign axi_aid_o=axi_atype_o?axi_awid_i:axi_arid_i;
        assign axi_aaddr_o=axi_atype_o?axi_awaddr_i:axi_araddr_i;
        assign axi_alen_o=axi_atype_o?axi_awlen_i:axi_arlen_i;
    
    
    
endmodule
