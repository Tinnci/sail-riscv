/*=======================================================================================*/
/*  Venus Extension: Instruction Definitions                                             */
/*                                                                                       */
/*  当前仅添加 VENUS_MSB 入口指令的占位实现，以验证解码钩子。                             */
/*=======================================================================================*/

/* 将整条 32-bit 指令作为参数保存，方便后续调试 */
union clause ast = VENUS_MSB : bits(32)

/* 执行语义占位：打印信息并 PC += 4                                                    */
function clause execute VENUS_MSB(instr) = {
  print_string("[Venus] VENUS_MSB instruction hooked!", "");
  let pc = PC;
  PC = pc + 4;
  RETIRE_SUCCESS
} 