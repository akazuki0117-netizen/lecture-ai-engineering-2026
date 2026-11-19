#!/usr/bin/env bash
# 第5回 演習（STEP 1〜4）と宿題（基礎：RAG_TOP_K を変える）をまとめて実行し、lectures/05/runs/ に残す。
# Codespaces で 1 回実行する（約 10 分）。
# 使い方: bash lectures/05/run_compare.sh
set -u
RUNS=lectures/05/runs
Q_LORA='第2回の説明では、LoRAは何を固定し何を学習しますか？ QLoRAは何を加えますか？'
Q_MULTI='第3回の例では、コンパクションとセッションをまたぐメモリはどう違いますか。日々のメモはすべて長期メモリに入りますか'

if ! git diff --quiet -- app/config.py; then
  echo "app/config.py に未 commit の変更があります。commit してから実行してください。"
  exit 1
fi
trap 'git restore app/config.py' EXIT
mkdir -p "$RUNS"

# run <名前> <引数...>: 実行して表示を <名前>.txt に残す。レート制限に当たらないよう間をあける
run() {
  local name=$1; shift
  echo "===== $name: $* ====="
  uv run python -m app.agent --trace "$@" 2>&1 | tee "$RUNS/$name.txt"
  sleep 25
}
# set_top_k <件数>: app/config.py の RAG_TOP_K を書き換える
set_top_k() {
  sed -i "s/^RAG_TOP_K = .*/RAG_TOP_K = $1/" app/config.py
  grep -q "^RAG_TOP_K = $1$" app/config.py || { echo "RAG_TOP_K を $1 にできませんでした"; exit 1; }
}

# ---- 演習 ----
run step1_full_context --full-context "$Q_LORA"
uv run python -m app.retrieval "LoRA QLoRA 違い" 2>&1 | tee "$RUNS/step2_retrieval.txt"
sleep 10
run step3_vector_1 "$Q_LORA"
run step3_vector_2 "$Q_LORA"   # 同じ条件で揺れを見るため 2 回
run step4_tree --tree "$Q_LORA"
run step4_graph --graph "$Q_LORA"

# ---- 宿題（基礎）：RAG_TOP_K（通常のベクトル検索で返す件数）だけを 5 → 2 / 10 に変える ----
# 複数ページにまたがる質問でも比べる（根拠：第3回 PDF p.13、39、40）
run hw_k5_multi "$Q_MULTI"
for K in 2 10; do
  set_top_k "$K"
  uv run python -m app.retrieval "LoRA QLoRA 違い" 2>&1 | tee "$RUNS/hw_k${K}_retrieval.txt"
  sleep 10
  run "hw_k${K}_lora_1" "$Q_LORA"
  run "hw_k${K}_lora_2" "$Q_LORA"
  run "hw_k${K}_multi" "$Q_MULTI"
done

echo "完了: $RUNS に記録しました"
