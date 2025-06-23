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

/* 临时读取 DSPM 的辅助函数（仅返回魔法数位置） */
function venus_dspm_load(row:int, lane:int) -> bits(32) = {
  assert(row < venus_dspm_row, "DSPM row index is out of bounds!");
  assert(lane < venus_dspm_lane, "DSPM lane index is out of bounds!");

  let row_bits_idx  = to_bits_truncate(8, row);
  let lane_bits_idx = to_bits_truncate(4, lane);

  let row_vec = vector_access(VENUS_DSPM, unsigned(row_bits_idx));
  vector_access(row_vec, unsigned(lane_bits_idx))
}

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
  /* 24-bit 立即数，用于向量长度等参数 */
  let imm24    : bits(24) = venus_inst[55 .. 32];

  /* ----------------- 指令分发 ---------------------- */
  match v_opcode {
    0b00000001 => {  /* ===== VLOAD (示例 opcode 0x01) ===== */
      print_bits("[Venus] VLOAD inst bits = ", venus_inst);

      /* 元素字节数：当前固定为 4B，可按实际规格调整 */
      let elem_bytes : int = 4;

      /* 向量长度由 imm24 指定，若为 0 则视为 1 以避免空循环 */
      let tmp_vlen : int = unsigned(imm24);
      let vlen : int = if tmp_vlen == 0 then 1 else tmp_vlen;

      let base_addr : xlenbits = X(rs1);

      /* 累加读取结果，便于一次性写回 rd */
      var result : xlenbits = zeros();

      foreach (i from 0 to (vlen - 1)) {
        let lane : int = i % venus_dspm_lane;
        let row  : int = i / venus_dspm_lane;

        /* 越界检查 */
        assert(row < venus_dspm_row, "DSPM row index is out of bounds!");
        assert(lane < venus_dspm_lane, "DSPM lane index is out of bounds!");

        /* 直接从 DSPM 读取（暂仅支持 row=0,lane=0，以确保类型检查通过） */
        let dspm_val : bits(32) = venus_dspm_load(row, lane);

        print_bits("[Venus] VLOAD dspm_val = ", dspm_val);
        result = zero_extend(xlen, dspm_val);
      };

      /* 写回 rd */
      print_bits("[Venus] VLOAD result = ", result);
      X(rd) = result;
      ()
    },
    0b00000010 => {  /* ===== VSTORE ===== */
      print_bits("[Venus] VSTORE inst bits = ", venus_inst);

      /* 元素字节数同样固定为 4B */
      let elem_bytes : int = 4;

      let tmp_vlen : int = unsigned(imm24);
      let vlen : int = if tmp_vlen == 0 then 1 else tmp_vlen;

      /* rs1 = 数据源，rs2 = DSPM 基地址（当前未使用，可后续扩展） */
      let data_to_store_full : xlenbits = X(rs1);
      let data_to_store      : bits(32) = trunc(32, data_to_store_full);

      let base_addr : xlenbits = X(rs2);

      foreach (i from 0 to (vlen - 1)) {
        let lane : int = i % venus_dspm_lane;
        let row  : int = i / venus_dspm_lane;

        assert(row < venus_dspm_row, "DSPM row index is out of bounds!");
        assert(lane < venus_dspm_lane, "DSPM lane index is out of bounds!");

        /*
         * 使用 vector_update + <- 更新状态寄存器
         */
        let row_bits_idx  = to_bits_truncate(8, row);
        let lane_bits_idx = to_bits_truncate(4, lane);

        let current_row = vector_access(VENUS_DSPM, unsigned(row_bits_idx));
        let updated_row = vector_update(current_row, unsigned(lane_bits_idx), data_to_store);
        VENUS_DSPM = vector_update(VENUS_DSPM, unsigned(row_bits_idx), updated_row);
      };
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