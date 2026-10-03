module logic_gates (
    input wire a,
    input wire b,
    output wire y_and,
    output wire y_or,
    output wire y_not_a,
    output wire y_nand,
    output wire y_nor,
    output wire y_xor,
    output wire y_xnor
);

and u_and (y_and, a, b);
or u_or (y_or, a, b);
not u_inv (y_not_a, a);
nand u_nand (y_nand, a, b);
nor u_nor (y_nor, a, b);
xor u_xor (y_xor, a, b);
xnor u_xnor (y_xnor, a, b);

endmodule
