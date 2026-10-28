`timescale 1ns / 1ps

module els_axi_aw_ar_mux #(
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4
)
(

    input axi_atype,
    
    //aw:
    input [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_i,
    input m_axi_awvalid_i,
    input [7:0] m_axi_awlen_i,
    input [AXI_ID_WIDTH-1:0] m_axi_m_axi_awid_i,
    
    output reg m_axi_awready_o,
    
    //ar:
    input [AXI_ADDR_WIDTH-1:0] m_axi_araddr_i,
    input m_axi_arvalid_i,
    input [7:0] m_axi_arlen_i,
    input [AXI_ID_WIDTH-1:0] m_axi_m_axi_arid_i,
    
    output reg m_axi_arready_o,
    
    //a:
    input m_axi_aready_i,
    
    output reg [AXI_ID_WIDTH-1:0] m_axi_m_axi_aid_o,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_aaddr_o,
    output reg [7:0] m_axi_alen_o,
    output reg m_axi_atype_o,
    output reg m_axi_avalid_o

    );
    
    always @ (*)
    case(axi_atype)
    //rd:
    0:begin
        m_axi_atype_o<=0;
        
        m_axi_m_axi_aid_o<=m_axi_m_axi_arid_i;
        m_axi_aaddr_o<=m_axi_araddr_i;
        m_axi_alen_o<=m_axi_arlen_i;
        m_axi_avalid_o<=m_axi_arvalid_i;
        
        m_axi_arready_o<=m_axi_aready_i;
    end
    
    //wr:
    1:begin
        m_axi_atype_o<=1;
        
        m_axi_m_axi_aid_o<=m_axi_m_axi_awid_i;
        m_axi_aaddr_o<=m_axi_awaddr_i;
        m_axi_alen_o<=m_axi_awlen_i;
        m_axi_avalid_o<=m_axi_awvalid_i;
        
        m_axi_awready_o<=m_axi_aready_i;
    end
    
    default:;
    endcase
    
    
endmodule
