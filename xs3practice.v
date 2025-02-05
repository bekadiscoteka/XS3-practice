`define NIBBLE0 [3:0]
`define NIBBLE1 [7:4]
`define NIBBLE2 [11:8]
`define NIBBLE3 [15:12]



/* 
modules implemented only using dataflow/gate modeling

set of avaliable functions:
    XS3_2DIGIT_ADDER
    XS3_2DIGIT_SUBTRACTOR
    BINARY_TO_XS3_2_DIGIT_CONVERTER
    XS3_TO_BINARY_2_DIGIT_CONVERTER
*/

module xs3_half_adder(out, c_out, a, b);
output `NIBBLE0 out;
output c_out;
wire `NIBBLE0 result;
input `NIBBLE0 a, b;
assign result = a + b;
assign c_out  = (a[3] ^ b[3]) & ((a[2] ^ b[2]) & ((a[1] ^ b[1]) & (a[0] & b[0]) | a[1] & b[1]) | a[2] & b[2]) | a[3] & b[3];
assign out = ({4{c_out}} & (result + 4'd3)) | ({4{~c_out}} & (result - 4'd3));
endmodule;

module xs3_full_adder(out, c_out, a, b, c_in);
output `NIBBLE0 out;
input `NIBBLE0 a, b;
input c_in;
output c_out;
wire `NIBBLE0 ha_out;
wire ha_c_out, ha1_c_out;
xs3_half_adder ha(ha_out, ha_c_out, a, b);
xs3_half_adder ha1(out, ha1_c_out, ha_out, (c_in + 4'd3));
assign c_out = ha_c_out | ha1_c_out;
endmodule;

module XS3_2DIGIT_ADDER(out, c_out, a, b);
input [7:0] a, b;
output [7:0] out;
output c_out;
wire ha_c_out;
xs3_half_adder ha(out`NIBBLE0, ha_c_out, a`NIBBLE0, b`NIBBLE0);
xs3_full_adder fa(out`NIBBLE1, c_out, a`NIBBLE1, b`NIBBLE1, ha_c_out);
endmodule;

module XS3_2DIGIT_SUBTRACTOR(out, sign, a, b);
output [7:0] out;
input [7:0] a, b;
output sign;
wire [3:0] a0_c, a1_c, compBack0, compBack1, temp;  
wire [7:0] pre_out;
wire is_zero0, is_zero1, overflow0, overflow1, carry1, carry0; 
//taking 2's complements for xs3
xs3_half_adder ha0_c(a0_c, is_zero0, ~a[3:0], 4'b0100);
xs3_half_adder ha1_c(a1_c, is_zero1, ~a[7:4], 4'b0100);
// subtracting nibble0 of b from a
xs3_half_adder nibble0_subtr(pre_out[3:0], overflow0, a0_c, b[3:0]);
// same for more significant nibble 
xs3_half_adder nibble1_subtr(temp, overflow1, a1_c, b[7:4]); 
//calculating carries (borrows)
assign carry0 = (is_zero0 & (b[3:0] > 4'b0011)) |
    overflow0;
assign carry1 = (is_zero1 & (b[7:4] > 4'b0011)) |
    ((temp == 4'b0011) & carry0) |
    overflow1;
// considering carry from nibble0
xs3_half_adder nibble1_subtr2(pre_out[7:4], , temp, 
    (({4{~carry1 & carry0}} & 4'b0100) |
    ({4{~carry1 & ~carry0}} & 4'b0011) |
    ({4{carry1 & carry0}} & 4'b0011) |
    ({4{carry1 & ~carry0}} & 4'b0010)) 
);
//taking 2's complements back
xs3_half_adder nibble0_compBack(compBack0, , ~pre_out[3:0], 4'b0100);
xs3_half_adder nibble1_compBack(compBack1, , ~pre_out[7:4], 4'b0100);
//deciding if nibble will complement back or stay
assign out[3:0] = ({4{~carry1}} & compBack0) |
    ({4{carry1}} & pre_out[3:0]);
assign out[7:4] = ({4{~carry1}} & compBack1) |
    ({4{carry1}} & pre_out[7:4]);

buf (sign, carry1);

endmodule;


module BINARY_TO_XS3_2_DIGIT_CONVERTER(output [7:0] out, input [5:0] in);
wire [63:0] dec_out;
wire `NIBBLE0 enc0to9_out, enc10to19_out, enc20to29_out, 
	enc30to39_out, enc40to49_out, enc50to59_out, enc60to63_out;

decoder_6x64 decoder(dec_out, in);
//here goes encoders to BCD 
encoder enc_0to9(enc0to9_out, dec_out[9:0]);
encoder enc_10to9(enc10to19_out, dec_out[19:10]);
encoder enc_20to29(enc20to29_out, dec_out[29:20]);
encoder enc_30to39(enc30to39_out, dec_out[39:30]);
encoder enc_40to49(enc40to49_out, dec_out[49:40]);
encoder enc_50to59(enc50to59_out, dec_out[59:50]);
encoder enc_60to63(enc60to63_out, {6'd0 ,dec_out[63:60]});
wire [7:0] bcd_out;
assign bcd_out[3:0] = enc0to9_out | enc10to19_out |
   	enc20to29_out | enc30to39_out |
   	enc40to49_out | enc50to59_out |
   	enc60to63_out; 

//computing the second digit
wire [9:0] pre_encoder = {3'd0, |(dec_out[63:60]), |(dec_out[59:50]),
    |(dec_out[49:40]), |(dec_out[39:30]), |(dec_out[29:20]), |(dec_out[19:10]), 
    |(dec_out[9:0])}; 
encoder second_digit_enc(bcd_out[7:4], pre_encoder);
// converting bcd to xs3
bcd_XS3 convertBcdXs3(out, bcd_out);
endmodule;

module decoder_6x64(out, binary_code);
input [5:0] binary_code;
output [63:0] out;
assign out = 64'd1 << binary_code;
endmodule;

module bcd_XS3(output [7:0] out, input [7:0] bcd_out);
assign out`NIBBLE0 = bcd_out`NIBBLE0 + 4'd3;
assign out`NIBBLE1 = bcd_out`NIBBLE1 + 4'd3;
endmodule;

module encoder(out, in);
input [9:0] in;
output [3:0] out;

assign out = {(in[8] || in[9]), 
    (in[4] || in[5] || in[6] || in[7]), 
    (in[2] || in[3] || in[6] || in[7]), 
    (in[1] || in[3] || in[5] || in[7] || in[9])};
endmodule;

module XS3_TO_BINARY_2_DIGIT_CONVERTER(output [7:0] out, input [7:0] in);
//first converting to bcd
wire [7:0] bcd = {in[7:4] - 4'd3, in[3:0] - 4'd3};
assign out = ({4'd0, bcd[3:0]}) + (({4'd0, bcd[7:4]}) * 8'd10); 
endmodule;


