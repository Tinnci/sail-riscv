/*=======================================================================================*/
/*  Venus Extension: Instruction Definitions                                             */
/*                                                                                       */
/*  当前仅添加 VENUS_MSB 入口指令的占位实现，以验证解码钩子。                             */
/*=======================================================================================*/

/* 将整条 32-bit 指令作为参数保存，方便后续调试 */
union clause ast = VENUS_MSB : bits(32)

/* ************************************************************ */
/* Venus 64-bit 指令执行函数（当前为调试桩）                     */
/* ************************************************************ */

function execute_venus(venus_inst : bits(64)) -> unit = {
  print_bits("[Venus] Executing 64-bit Venus instruction: ", venus_inst)
}

/* ************************************************************ */
/* VENUS_MSB 执行：取指、拼接、转发                               */
/* ************************************************************ */

function clause execute VENUS_MSB(msb_inst) = {
  /* 计算下一指令地址（低 32 位） */
  let lsb_pc : xlenbits = PC + 4;

  /* 地址翻译：虚拟 -> 物理 */
  match translateAddr(Virtaddr(lsb_pc), InstructionFetch()) {
    Err(e, _) => {
      handle_exception(e);
      RETIRE_SUCCESS
    },
    Ok(paddr, _) => {
      /* 读取低 32 位指令 */
      match mem_read(InstructionFetch(), paddr, 4, false, false, false) {
        Err(e) => {
          handle_mem_exception(Virtaddr(lsb_pc), e);
          RETIRE_SUCCESS
        },
        Ok(lsb_bits) => {
          /* 拼接成为 64-bit Venus 指令，高位在前 */
          let venus_inst : bits(64) = append(msb_inst, lsb_bits);

          /* 调用核心执行逻辑 */
          execute_venus(venus_inst);

          /* 更新 PC：跳过两条 32-bit 指令 */
          PC = PC + 8;
          RETIRE_SUCCESS
        }
      }
    }
  }
} 