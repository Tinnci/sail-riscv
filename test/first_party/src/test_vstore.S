.section .text.init
.globl main
main:
    # 1. 准备要存储的数据
    li x11, 0xCAFED00D      # rs1 <- data to be stored

    # 2. 准备 VSTORE 的地址 (rs2=x12=0, base_addr=0)
    li x12, 0

    # 3. 执行 VSTORE, vlen=1
    # v_opcode=2, imm=1, rs2=12, rs1=11, rd=0
    .word 0x0200000B        # MSB: v_opcode=0x02, imm24=0, opcode=custom-0
    .word 0x00C5800B        # LSB: rs2=12(x12), rs1=11(x11), rd=0, opcode=custom-0

    # 4. 清空 x11，确保后续读到的值是来自 DSPM
    li x11, 0

    # 5. 执行 VLOAD, vlen=1
    # v_opcode=1, imm=1, rs2=12(addr=0), rs1=0(stride=0), rd=13
    .word 0x0100000B        # MSB: v_opcode=0x01, imm24=0, opcode=custom-0
    .word 0x00C0068B        # LSB: rs2=12(x12), rs1=0, rd=13(x13), opcode=custom-0

    # 6. 验证结果
    li x10, 0xCAFED00D
    bne x13, x10, fail

pass:
    li a0, 0
    ret
fail:
    li a0, 1
    ret

# (RVTEST_DATA removed) 