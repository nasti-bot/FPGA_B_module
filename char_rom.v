// char_rom：中文字模 ROM，16x16 点阵，每字 32 字节，逐行 MSB first。
// 字索引 0=圆 1=形 2=矩；地址 = {char_idx[1:0], row[3:0], byte_sel}，共 96 字节。
// 本模块以点阵实现文字显示，ROM 里每个字占 16 行，每行 16 列，分成两个字节存储。
module char_rom (
    input  wire [6:0] addr,
    output reg  [7:0] data
);

    reg [7:0] rom [0:95];
    initial begin
        rom[  0] = 8'h7F;   
        rom[  1] = 8'hFE;  
        rom[  2] = 8'h40;
        rom[  3] = 8'h02;
        rom[  4] = 8'h4F;
        rom[  5] = 8'hF2;
        rom[  6] = 8'h48;
        rom[  7] = 8'h12;
        rom[  8] = 8'h4F;
        rom[  9] = 8'hF2;
        rom[ 10] = 8'h40;
        rom[ 11] = 8'h02;
        rom[ 12] = 8'h4F;
        rom[ 13] = 8'hF2;
        rom[ 14] = 8'h48;
        rom[ 15] = 8'h12;
        rom[ 16] = 8'h49;
        rom[ 17] = 8'h92;
        rom[ 18] = 8'h49;
        rom[ 19] = 8'h12;
        rom[ 20] = 8'h43;
        rom[ 21] = 8'h42;
        rom[ 22] = 8'h4E;
        rom[ 23] = 8'h32;
        rom[ 24] = 8'h40;
        rom[ 25] = 8'h02;
        rom[ 26] = 8'h7F;
        rom[ 27] = 8'hFE;
        rom[ 28] = 8'h40;
        rom[ 29] = 8'h02;
        rom[ 30] = 8'h00;
        rom[ 31] = 8'h00;
        rom[ 32] = 8'h00;
        rom[ 33] = 8'h00;
        rom[ 34] = 8'h7F;
        rom[ 35] = 8'h8C;
        rom[ 36] = 8'h13;
        rom[ 37] = 8'h18;
        rom[ 38] = 8'h13;
        rom[ 39] = 8'h30;
        rom[ 40] = 8'h13;
        rom[ 41] = 8'h20;
        rom[ 42] = 8'h13;
        rom[ 43] = 8'h02;
        rom[ 44] = 8'h13;
        rom[ 45] = 8'h04;
        rom[ 46] = 8'h7F;
        rom[ 47] = 8'h88;
        rom[ 48] = 8'h13;
        rom[ 49] = 8'h30;
        rom[ 50] = 8'h13;
        rom[ 51] = 8'h20;
        rom[ 52] = 8'h33;
        rom[ 53] = 8'h02;
        rom[ 54] = 8'h23;
        rom[ 55] = 8'h06;
        rom[ 56] = 8'h23;
        rom[ 57] = 8'h0C;
        rom[ 58] = 8'h23;
        rom[ 59] = 8'h18;
        rom[ 60] = 8'h43;
        rom[ 61] = 8'h60;
        rom[ 62] = 8'h41;
        rom[ 63] = 8'h40;
        rom[ 64] = 8'h20;
        rom[ 65] = 8'h00;
        rom[ 66] = 8'h20;
        rom[ 67] = 8'hFE;
        rom[ 68] = 8'h20;
        rom[ 69] = 8'h80;
        rom[ 70] = 8'h3E;
        rom[ 71] = 8'h80;
        rom[ 72] = 8'h48;
        rom[ 73] = 8'h80;
        rom[ 74] = 8'h48;
        rom[ 75] = 8'hFE;
        rom[ 76] = 8'h08;
        rom[ 77] = 8'h86;
        rom[ 78] = 8'h7E;
        rom[ 79] = 8'h86;
        rom[ 80] = 8'h08;
        rom[ 81] = 8'h86;
        rom[ 82] = 8'h18;
        rom[ 83] = 8'h86;
        rom[ 84] = 8'h18;
        rom[ 85] = 8'hFE;
        rom[ 86] = 8'h1C;
        rom[ 87] = 8'h80;
        rom[ 88] = 8'h16;
        rom[ 89] = 8'h80;
        rom[ 90] = 8'h22;
        rom[ 91] = 8'h80;
        rom[ 92] = 8'h60;
        rom[ 93] = 8'hFE;
        rom[ 94] = 8'h40;
        rom[ 95] = 8'h80;
    end

    always @(*) begin
        data = rom[addr];
    end

endmodule
