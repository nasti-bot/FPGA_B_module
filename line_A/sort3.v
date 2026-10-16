// sort3: sort three 8-bit numbers into min, mid, max (small to big)
module sort3(
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [7:0] c,
    output wire [7:0] min,
    output wire [7:0] mid,
    output wire [7:0] max
);

    wire [7:0] ab_min, ab_max;

    // step1: compare a and b, pick smaller and bigger
    assign ab_min = (a < b) ? a : b;
    assign ab_max = (a < b) ? b : a;

    // step2: max = larger of (ab_max, c)
    assign max = (ab_max > c) ? ab_max : c;

    // step3: min = smaller of (ab_min, c)
    assign min = (ab_min < c) ? ab_min : c;

    // step4: mid = the one left over
    assign mid = a + b + c - min - max;

endmodule
