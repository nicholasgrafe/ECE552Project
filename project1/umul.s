## Author: James Park
##
## You may implement the following with any of the instructions in the RV32I instruction set
## and described in the reference sheet. Do not use any of the mul[h][s][u] instructions which
## are *not* described in the reference sheet. Remember to respect the calling convention - if
## you choose to use any of the callee saved registers s[0-11], remember to save them to the
## stack before reusing them (note, you should not need to do this but are free to do so).
##
## [Description]
## Multiplies two 32-bit *unsigned* numbers and provides a 32-bit *unsigned* result
## consisting of the lower 32 bits of the product.
##
## [Arguments]
## a0 = multiplicand
## a1 = multiplier
##
## [Returns]
## a0 = 32-bit product
    .text
    .globl umul
umul:
    add t1, zero, zero      # initialize index i to 0
    addi t2, zero, 32       # 32 bit counter
    add t0, zero, zero      # clear t0 (temp result value)

loop:
    andi t3, a0, 1          # check if LSB is a 1
    beq t3, zero, shift     # skip LSB if it's a 0
    add t0, t0, a1          # add the shifted multiplier to temp result

shift:
    slli a1, a1, 1          # shift multiplier by a bit each iteration
    srli a0, a0, 1          # shift a0 to check the new LSB
    addi t1, t1, 1          # increment index i
    bne t1, t2, loop        # if i < 32 --> continue loop

    add a0, t0, zero        # move temp result to a0
    jalr zero, 0(ra)
