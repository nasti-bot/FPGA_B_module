// rgb2gray：RGB888 转灰度。
// Y = (77R + 150G + 29B) >> 8，三个权重和正好 256，右移 8 位免费。
module rgb2gray(
    input  wire [7:0] R,
    input  wire [7:0] G,
    input  wire [7:0] B,
    output wire [7:0] Y
);

    assign Y = (77*R + 150*G + 29*B) >> 8;

endmodule
