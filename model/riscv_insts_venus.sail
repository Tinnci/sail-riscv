/*=======================================================================================*/
/*  Venus Extension: Instruction Definitions                                             */
/*                                                                                       */
/*  当前仅添加 VENUS_MSB 入口指令的占位实现，以验证解码钩子。                             */
/*=======================================================================================*/

/* 将整条 32-bit 指令作为参数保存，方便后续调试 */
union clause ast = VENUS_MSB : bits(32)

/* ************************************************************ */
/* Venus 辅助函数：地址与掩码计算                               */
/* ************************************************************ */

function get_abs_addr_and_mask(
  idx: int,
  is_vload: bool,
  is_vstore: bool,
  vldst_elem_bytes: int,
  base_addr: bits(xlen)
) -> (int, int, bits(16)) = {
  let lane : int = idx % venus_dspm_lane;
  let row  : int = idx / venus_dspm_lane;

  var bank : int = 0;
  var mask : bits(16) = zeros();

  if is_vload then {
    let offset_in_lane : int = unsigned(base_addr) + row * vldst_elem_bytes;
    bank = offset_in_lane / venus_dspm_lane;
    mask = zeros();
  } else if is_vstore then {
    bank = row % venus_dspm_bank_per_lane;
    mask = zeros();
  } else {
    bank = 0;
    mask = zeros();
  };

  let row_abs : int = row / venus_dspm_bank_per_lane;
  (row_abs, bank, mask)
}

/* ************************************************************ */
/* Venus 64-bit 指令执行函数（当前为调试桩）                     */
/* ************************************************************ */

function execute_venus(venus_inst : bits(64)) -> unit = {
  /* ----------------- 指令字段提取 ------------------ */
  let v_opcode : bits(8) = venus_inst[63 .. 56];
  let rs2      : regidx  = Regidx(venus_inst[24 .. 20]);
  let rs1      : regidx  = Regidx(venus_inst[19 .. 15]);
  let rd       : regidx  = Regidx(venus_inst[11 .. 7]);

  /* ----------------- 指令分发 ---------------------- */
  match v_opcode {
    0b00000001 => {  /* ===== VLOAD (示例 opcode 0x01) ===== */
      print_bits("[Venus] VLOAD inst bits = ", venus_inst);

      /* 示例: 固定向量长度与元素字节数，可根据 imm 字段替换 */
      let vlen : int              = 64;
      let elem_bytes : int        = 4;

      let base_addr : xlenbits = X(rs1);
      let stride    : xlenbits = X(rs2);

      foreach (i from 0 to (vlen - 1)) {
        let (row_abs, bank, mask) = get_abs_addr_and_mask(i, true, false, elem_bytes, base_addr);

        /* 仅示例读取: 实际实现需依据 bank 访问不同物理块 */
        let dspm_val : bits(32) = zeros();

        /* 这里示例将最后一个元素写回 rd */
        if i == vlen - 1 then {
          X(rd) = zero_extend(xlen, dspm_val);
        };
      };
      ()
    },
    0b00000010 => {
      print_string("[Venus] VSTORE not implemented yet\n", "");
      ()
    },
    _ => {
      print_bits("[Venus] Unknown opcode = ", v_opcode);
      handle_illegal(venus_inst[31 .. 0]);
    }
  }
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

          /* 更新 PC：跳过两条 32-bit 指令（覆盖 run_hart_active 预设的 +4） */
          set_next_pc(PC + 8);
          RETIRE_SUCCESS
        }
      }
    }
  }
}

/* ************************************************************ */
/* ASM 打印支持：简单十六进制输出                                   */
/* ************************************************************ */

mapping clause assembly = VENUS_MSB(bits) <-> "venus.msb" ^ spc() ^ hex_bits_32(bits) 