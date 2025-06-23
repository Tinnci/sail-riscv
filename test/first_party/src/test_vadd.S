.section .text.init
.globl main
main:
    # 期望结果 300 存到 x14
    li x14, 300

    # 执行 VADD (opcode 0x03), rd=x13
    # MSB
    .word 0x0300000B
    # LSB: rd=13(0x0D), rs1=0, rs2=0, opcode custom-0 (0x0B)
    .word 0x0000068B

    # 检查结果
    bne x13, x14, fail

pass:
    li a0, 0
    ret
fail:
    li a0, 1
    ret 