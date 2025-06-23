.global main
main:
    # 设置输入寄存器
    li x11, 0x1000         # rs1 (base addr)
    li x12, 0x4            # rs2 (stride)
    li x13, 0xBADF00D      # rd 预置

    # 手动编码 64-bit VLOAD
    # MSB：高 8 位 v_opcode=0x01；低 7 位 custom-0 opcode=0x0B
    .word 0x0100000B       # MSB (bits[31:24]=0x01, bits[6:0]=0x0B)

    # LSB：rs2=x12(12)、rs1=x11(11)、rd=x13(13)
    #  rs2 -> bits[24:20] = 0b01100 = 0x0C
    #  rs1 -> bits[19:15] = 0b01011 = 0x0B
    #  rd  -> bits[11:7]  = 0b01101 = 0x0D
    .word 0x00C58680       # LSB

    # 当前 Sail 实现应将 x13 写 0
    bnez x13, fail

pass:
    li a0, 0
    ret
fail:
    li a0, 1
    ret 