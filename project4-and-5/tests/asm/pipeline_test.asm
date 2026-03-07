# Pipeline test: RAW hazards + branch delay slots
# Tests a chain of dependent addi instructions followed by a beq.
# With BYPASS_EN=1 and branch resolved in EX, we need:
#   - 2 NOPs between back-to-back RAW-dependent instructions
#   - 2 NOPs after every branch (branch delay slots)
#
# Expected result: branch is TAKEN (x6 == x7 == 15), so we reach L10.
# a0 (x10) should be 0x1000 at ebreak.

.section .text
.globl _start
_start:
    addi x7, x0, 15        # x7 = 15
    addi x1, x0, 10        # x1 = 10  (no dependency on x7)
    nop                     # \
    nop                     #  > 2 NOPs: x1 RAW hazard (L1 -> L2)
    addi x2, x1, 1         # x2 = 11
    nop                     # \
    nop                     #  > 2 NOPs: x2 RAW hazard (L2 -> L3)
    addi x3, x2, 1         # x3 = 12
    nop                     # \
    nop                     #  > 2 NOPs: x3 RAW hazard (L3 -> L4)
    addi x4, x3, 1         # x4 = 13
    nop                     # \
    nop                     #  > 2 NOPs: x4 RAW hazard (L4 -> L5)
    addi x5, x4, 1         # x5 = 14
    nop                     # \
    nop                     #  > 2 NOPs: x5 RAW hazard (L5 -> L6)
    addi x6, x5, 1         # x6 = 15
    nop                     # \
    nop                     #  > 2 NOPs: x6 RAW hazard (L6 -> beq)
    beq x6, x7, taken       # branch taken: 15 == 15
    nop                     # \
    nop                     #  > 2 NOPs: branch delay slots (always execute)
not_taken:
    lui x10, 0xdead0        # should NOT execute (a0 = 0xdead0000)
    ebreak

taken:
    lui x10, 1              # a0 = 0x00001000
    ebreak
