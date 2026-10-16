// 3x3 窗口生成器：把一串像素流，变成 9 个并行的像素（3行 x 3列）
// 输入：din（像素流，逐行流入，每行 WIDTH 个像素）
// 输出：9 个像素，组成以「中间行第 N 列」为中心的 3x3 窗口
module window3x3 #(
    parameter WIDTH = 4    // 一行像素个数（先用4做小例子）
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] din,
    // 输出的 3x3 窗口（命名对应 sobel_core 的 P0~P8）
    output wire [7:0] w00, w01, w02,
    output wire [7:0] w10, w11, w12,
    output wire [7:0] w20, w21, w22
);

    // 三行同列
    wire [7:0] r0, r1, r2;
    assign r0 = din;   // 当前行

    line_buffer #(.WIDTH(WIDTH)) lb1 (
        .clk(clk), .rst_n(rst_n), .din(din), .dout(r1)  // 上一行
    );
    line_buffer #(.WIDTH(WIDTH)) lb2 (
        .clk(clk), .rst_n(rst_n), .din(r1), .dout(r2)   // 上上行
    );

    // 每一行再延迟1拍、2拍，得到左右邻居
    reg [7:0] r0_d1, r0_d2, r1_d1, r1_d2, r2_d1, r2_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0_d1 <= 0; r0_d2 <= 0;
            r1_d1 <= 0; r1_d2 <= 0;
            r2_d1 <= 0; r2_d2 <= 0;
        end else begin
            r0_d1 <= r0;  r0_d2 <= r0_d1;
            r1_d1 <= r1;  r1_d2 <= r1_d1;
            r2_d1 <= r2;  r2_d2 <= r2_d1;
        end
    end

    // 3x3 窗口输出
    //   w00 w01 w02   =   r2_d2 r2_d1 r2
    //   w10 w11 w12   =   r1_d2 r1_d1 r1
    //   w20 w21 w22   =   r0_d2 r0_d1 r0
    assign w00 = r2_d2; assign w01 = r2_d1; assign w02 = r2;
    assign w10 = r1_d2; assign w11 = r1_d1; assign w12 = r1;
    assign w20 = r0_d2; assign w21 = r0_d1; assign w22 = r0;

endmodule
