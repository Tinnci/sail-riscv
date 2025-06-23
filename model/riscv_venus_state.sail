/*=======================================================================================*/
/*  Venus Extension: Architectural State                                                 */
/*                                                                                       */
/*  NOTE: 仅为占位示例，后续可根据硬件规格扩充。                                          */
/*=======================================================================================*/

/* 256 行 × 16 列，每元素 16bit 的向量存储（占位定义，后续可替换为更精确数组类型） */

/* 先声明初始化函数，再使用 */

/* ------------------------------------------------------------------ */
/* Venus 扩展内存组织常量                                             */
/* ------------------------------------------------------------------ */

type venus_dspm_row            : Int = 256
let  venus_dspm_row            = sizeof(venus_dspm_row)

type venus_dspm_lane           : Int = 16
let  venus_dspm_lane           = sizeof(venus_dspm_lane)

type venus_dspm_bank_per_lane  : Int = 2
let  venus_dspm_bank_per_lane  = sizeof(venus_dspm_bank_per_lane)

type venus_mask_size           : Int = 8192  /* 256 * 16 * 2 */
let  venus_mask_size           = sizeof(venus_mask_size) 

/* ------------------------------------------------------------------ */
/* DSPM 初始内容：放置测试用魔法数                                     */
/* ------------------------------------------------------------------ */

function init_venus_dspm() -> vector(venus_dspm_row, vector(venus_dspm_lane, bits(32))) = {
  /* 全零初始化 */
  var v : vector(venus_dspm_row, vector(venus_dspm_lane, bits(32))) = vector_init(vector_init(zeros()));
  /* 在 (row=0, lane=0) 位置写入魔法数 */
  v[0][0] = 0xABCD1234;
  v
}

register VENUS_DSPM : vector(256, vector(16, bits(32))) = init_venus_dspm()

/* 8 192 位掩码缓存，用 bool 表示（占位定义） */
register VENUS_MASK_DSPM : vector(8192, bool) = vector_init(false)

/* 用于在 MSB/LSB 之间临时传递 64-bit 指令，后续可视情况删除 */
register VENUS_DECODE_TEMP : bits(64) 