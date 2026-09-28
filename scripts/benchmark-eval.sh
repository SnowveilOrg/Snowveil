#!/usr/bin/env bash
# Snowveil 求值性能基准工具。
#
# 选取覆盖框架不同层次的 flake 属性，测量 Nix 求值器的开销。属性刻意挑那些
# 会被惰性地求值、但不会强制实例化整个 nixpkgs 的路径 —— nixpkgs 实例化是绝对
# 主导成本，会把框架层面的回归完全掩盖掉。
#
# 用法：
#   scripts/benchmark-eval.sh [flake-ref] [attr] [attr...]
#   scripts/benchmark-eval.sh --suite                # 跑默认预设套件
#   scripts/benchmark-eval.sh --list                 # 打印预设套件
#   FORMAT=json scripts/benchmark-eval.sh --suite    # 逐行 JSON，便于 diff
#
# 环境变量：
#   RUNS     每个属性的重复次数（默认 3）
#   FORMAT   lines | json（默认 lines）
set -euo pipefail

# 套件按「求值深度」排序，方便定位回归出现在哪一层。
# 顶层 flake 的 checks 由 tests/flake-checks 生成，覆盖发现/选择/诊断各层；
# examples/basic 的 snowveil-* 诊断检查无法离线寻址（lock 里的相对 path:../..），
# 因此不放进默认套件。
DEFAULT_SUITE=(
  # 基准线：只触达 flake 表层，几乎不进入框架逻辑
  lib.snowveil.version.string
  # 输出面校验：发现 + systems 推导 + 各命名输出展开
  checks.x86_64-linux.surface.drvPath
  checks.x86_64-linux.outputcontrol.drvPath
  # 模块图：依赖图构建与拓扑排序
  checks.x86_64-linux.modulegraph.drvPath
  # profile 解析与角色过滤选择
  checks.x86_64-linux.profiles.drvPath
  checks.x86_64-linux.rolefilter.drvPath
  # home-manager 嵌入求值（每主机选择模块的代价）
  checks.x86_64-linux.homeEmbedded.drvPath
  # 完整 NixOS 主机配置求值（真正的大头：每主机独立的 evalModules）
  checks.x86_64-linux.host.drvPath
  # 跨系统组合：aarch64 侧的完整主机求值
  checks.aarch64-linux.host.drvPath
  # eval 控制面：诊断裁剪 / 选择性求值 / 无效输出校验（最重的组合检查）
  checks.x86_64-linux.evalcontrols.drvPath
  checks.aarch64-linux.evalcontrols.drvPath
)

format=${FORMAT:-lines}
runs=${RUNS:-3}
flake_ref=
suite=()

while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      printf '%s\n' "${DEFAULT_SUITE[@]}"
      exit 0
      ;;
    --suite)
      suite=("${DEFAULT_SUITE[@]}")
      shift
      ;;
    *)
      if [ -z "$flake_ref" ]; then
        flake_ref=$1
      else
        suite+=("$1")
      fi
      shift
      ;;
  esac
done

flake_ref=${flake_ref:-path:.}
if [ ${#suite[@]} -eq 0 ]; then
  suite=("${DEFAULT_SUITE[@]}")
fi

if ! [[ $runs =~ ^[1-9][0-9]*$ ]]; then
  echo "RUNS must be a positive integer" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to parse evaluator stats" >&2
  exit 2
fi

# nix eval 把 NIX_SHOW_STATS 的 JSON 打到 stderr；从第一个 '{' 起截取。
extract_stats() {
  sed -n '/^{/,$p' "$1" | tr -d '\n'
}

# 求值一次并打印结果，把墙上时间写进全局 LAST_WALL 供汇总比较。
LAST_WALL=
run_one() {
  local attr=$1 run=$2
  local stats_file stats
  stats_file=$(mktemp)

  # 用 bash 内建 time + TIMEFORMAT 取墙上时间，避免依赖外部 time 的具体路径。
  LAST_WALL=$(
    {
      TIMEFORMAT=%R
      time env NIX_SHOW_STATS=1 nix eval \
        --offline \
        --no-eval-cache \
        --raw \
        "${flake_ref}#${attr}" \
        >/dev/null 2>"$stats_file"
    } 2>&1
  ) || true

  stats=$(extract_stats "$stats_file" || true)
  rm -f "$stats_file"

  if [ -z "$stats" ]; then
    printf 'attribute %s produced no evaluator stats\n' "$attr" >&2
    LAST_WALL=
    return 1
  fi

  if [ "$format" = json ]; then
    printf '{"attribute":"%s","run":%d,"wall":%s,"evaluator":%s}\n' \
      "$attr" "$run" "$LAST_WALL" "$stats"
  else
    printf '  %-56s run %d  %7.2fs  cpu %8.2fs  calls %10s  thunks %10s\n' \
      "$attr" "$run" "$LAST_WALL" \
      "$(printf '%s' "$stats" | jq -r '.cpuTime')" \
      "$(printf '%s' "$stats" | jq -r '.nrFunctionCalls')" \
      "$(printf '%s' "$stats" | jq -r '.nrThunks')"
  fi
}

printf 'flake: %s\nruns: %s\n\n' "$flake_ref" "$runs"

# 汇总取最小值而非平均值：求值开销是确定性的，较大值只反映机器噪声。
summary=()
for attr in "${suite[@]}"; do
  [ "$format" = json ] || printf '%s\n' "$attr"
  best=
  for run in $(seq 1 "$runs"); do
    if ! run_one "$attr" "$run"; then
      continue
    fi
    if [ -z "$best" ] || awk "BEGIN{exit !($LAST_WALL < $best)}"; then
      best=$LAST_WALL
    fi
  done

  if [ "$format" != json ] && [ -n "$best" ]; then
    summary+=("$(printf '%-56s %7.2fs  (best of %s)' "$attr" "$best" "$runs")")
  fi
done

if [ "$format" != json ] && [ ${#summary[@]} -gt 0 ]; then
  printf '\nSummary (best run per attribute):\n'
  printf '  %s\n' "${summary[@]}"
fi
