#!/usr/bin/env bash
# run_compare.sh のうち、混雑（503）やレート制限で失敗した実行だけを、同じ条件で取り直す。
# 使い方: bash lectures/05/rerun_failed.sh（run_compare.sh が終わってから）
set -u
RUNS=lectures/05/runs
Q_LORA='第2回の説明では、LoRAは何を固定し何を学習しますか？ QLoRAは何を加えますか？'
Q_MULTI='第3回の例では、コンパクションとセッションをまたぐメモリはどう違いますか。日々のメモはすべて長期メモリに入りますか'
TRIES=4
WAIT=60

if ! git diff --quiet -- app/config.py; then
  echo "app/config.py に未 commit の変更があります。commit してから実行してください。"
  exit 1
fi
trap 'git restore app/config.py' EXIT

# 実行名 → 検索件数（RAG_TOP_K）と引数。run_compare.sh と同じ条件にそろえる
declare -A K=(
  [step1_full_context]=5 [step3_vector_1]=5 [step3_vector_2]=5 [step4_tree]=5 [step4_graph]=5
  [hw_k5_multi]=5
  [hw_k2_lora_1]=2 [hw_k2_lora_2]=2 [hw_k2_multi]=2
  [hw_k10_lora_1]=10 [hw_k10_lora_2]=10 [hw_k10_multi]=10
)
args_for() {
  case $1 in
    step1_full_context) echo "--full-context|$Q_LORA" ;;
    step4_tree)         echo "--tree|$Q_LORA" ;;
    step4_graph)        echo "--graph|$Q_LORA" ;;
    *_multi)            echo "|$Q_MULTI" ;;
    *)                  echo "|$Q_LORA" ;;
  esac
}
failed() { grep -qE "混み合っています|レート制限" "$1"; }

for name in "${!K[@]}"; do
  file="$RUNS/$name.txt"
  [ -f "$file" ] && ! failed "$file" && continue
  sed -i "s/^RAG_TOP_K = .*/RAG_TOP_K = ${K[$name]}/" app/config.py
  IFS='|' read -r mode question <<< "$(args_for "$name")"
  for i in $(seq 1 "$TRIES"); do
    echo "===== $name（取り直し $i 回目、RAG_TOP_K=${K[$name]}） ====="
    # shellcheck disable=SC2086
    uv run python -m app.agent --trace $mode "$question" 2>&1 | tee "$file"
    failed "$file" || break
    echo "まだ失敗しています。${WAIT} 秒待って取り直します"
    sleep "$WAIT"
  done
  git restore app/config.py
  sleep 20
done

echo "--- まだ失敗している実行（空なら全部そろいました）"
for f in "$RUNS"/*.txt; do failed "$f" && echo "$f"; done
