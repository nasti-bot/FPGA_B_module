`timescale 1ns / 1ps


//TMDS编码器模块，把待发送数据进行编码：
module els_tmds_encoder (
    input clk,
    input reset_n,
    
    input [7:0] data_in,
    
    input c0,
    input c1,
    input de,
    
    output reg [9:0] q_out
    
    );
   

  //////////////
  //////////////
  //对各信号进行打两拍的操作，以对齐周期：
      //后面带_sync0表示是打了一拍后的；带_sync1表示是打了两拍后的。
  
    reg [8:0] q_m;
    reg [8:0] q_m_sync0;
    
    reg c0_sync0,c0_sync1,
        c1_sync0,c1_sync1;
        
    reg de_sync0,de_sync1;
  
    always @ (posedge clk)
    begin
    q_m_sync0<=q_m;
    
    c0_sync1<=c0_sync0;
    c0_sync0<=c0;
    
    c1_sync1<=c1_sync0;
    c1_sync0<=c1;
    
    de_sync1<=de_sync0;
    de_sync0<=de;
    
    end
  
  
  ///////////////////
  //////////////////
  //TMDS编码过程：具体过程需参考流程图
  
    reg [7:0] din_q;
    
    reg [3:0] n1_d,n1_q_m_7_0,n0_q_m_7_0;
    
    reg [3:0] cnt;
  
    wire decision1,decision2,decision3;
    
    always @ (posedge clk)
    begin
        din_q<=data_in;
        n1_d<=data_in[0]+data_in[1]+data_in[2]+data_in[3]+data_in[4]+data_in[5]+data_in[6]+data_in[7];
        end
        
    assign decision1=(n1_d>4)||(n1_d==4&&din_q[0]==0);
        
    always @(*)
    case(decision1)
    
    0:begin
        q_m[0]=din_q[0];
        q_m[1]=q_m[0]^din_q[1];
        q_m[2]=q_m[1]^din_q[2];
        q_m[3]=q_m[2]^din_q[3];
        q_m[4]=q_m[3]^din_q[4];
        q_m[5]=q_m[4]^din_q[5];
        q_m[6]=q_m[5]^din_q[6];
        q_m[7]=q_m[6]^din_q[7];
        q_m[8]=1;
        end
        
    1:begin
        q_m[0]=din_q[0];
        q_m[1]=q_m[0]^~din_q[1];
        q_m[2]=q_m[1]^~din_q[2];
        q_m[3]=q_m[2]^~din_q[3];
        q_m[4]=q_m[3]^~din_q[4];
        q_m[5]=q_m[4]^~din_q[5];
        q_m[6]=q_m[5]^~din_q[6];
        q_m[7]=q_m[6]^~din_q[7];
        q_m[8]=0;
        end
        
    default:;
    endcase
    
    
    always @ (posedge clk)
    begin
    
    n1_q_m_7_0<=q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
    
    n0_q_m_7_0<=!q_m[0]+!q_m[1]+!q_m[2]+!q_m[3]+!q_m[4]+!q_m[5]+!q_m[6]+!q_m[7];
    
    end
    
    assign decision2=(cnt==0)||(n1_q_m_7_0==n0_q_m_7_0);
    
    assign decision3=(cnt>0&&n1_q_m_7_0>n0_q_m_7_0)||(cnt<0&&n1_q_m_7_0<n0_q_m_7_0);
    
    
    localparam CTL0=10'b11_0101_0100;
    localparam CTL1=10'b00_1010_1011;
    localparam CTL2=10'b01_0101_0100;
    localparam CTL3=10'b10_1010_1011;
    
    always @ (posedge clk or negedge reset_n)
    if(!reset_n) begin
        q_out<=0;
        cnt<=0;
        end
        
    else if(!de_sync1) begin
        cnt<=0;
        
        case({c1,c0})
        2'b00:q_out<=CTL0;
        2'b01:q_out<=CTL1;
        2'b10:q_out<=CTL2;
        2'b11:q_out<=CTL3;
        default:q_out<=0;
        endcase
        end
        
    else if(de_sync1) begin
    
        if(decision2) begin
            q_out[9]<=~q_m_sync0[8];
            q_out[8]<=q_m_sync0[8];
            q_out[7:0]<=q_m_sync0[8]?q_m_sync0[7:0]:~q_m_sync0[7:0];
            
            cnt<=!q_m_sync0[8]?(cnt+n0_q_m_7_0-n1_q_m_7_0):(cnt+n1_q_m_7_0-n0_q_m_7_0);
            end
            
        else if(decision3) begin
            q_out[9]<=1;
            q_out[8]<=q_m_sync0[8];
            q_out[7:0]<=~q_m_sync0[7:0];
            
            cnt<=cnt+2*q_m_sync0[8]+n0_q_m_7_0-n1_q_m_7_0;
            end
            
        else begin
        
            q_out[9]<=0;
            q_out[8]<=q_m_sync0[8];
            q_out[7:0]<=q_m_sync0[7:0];
            
            cnt<=cnt-2*~q_m_sync0[8]+n1_q_m_7_0-n0_q_m_7_0;
            
            end
        end
        
  ///////////////////////
  //////////////////////
    
endmodule
