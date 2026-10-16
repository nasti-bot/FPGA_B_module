// 彩色转灰度：Y = (77R + 150G + 29B) / 256
// 除以256 = 右移8位
module rgb2gray(
    input  wire [7:0] R,   // 红
    input  wire [7:0] G,   // 绿
    input  wire [7:0] B,   // 蓝
    output wire [7:0] Y    // 亮度
);

    assign Y = (77*R + 150*G + 29*B) >> 8;

endmodule
