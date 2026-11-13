#!/usr/bin/env bash
# 第4回 演習（STEP 2・3）と宿題（基礎：判定の順序）の採点をまとめて実行し、lectures/04/runs/ に残す。
# STEP 1 のラベル付け（lectures/04/labels.jsonl）が終わってから、Codespaces で 1 回実行する（約 6 分）。
# 使い方: bash lectures/04/run_judge.sh
set -u
RUNS=lectures/04/runs
WAIT=4  # 1 件ごとに待つ秒数。無料枠のレート制限（毎分 15 リクエスト）に当たらないよう

if [ ! -f lectures/04/labels.jsonl ]; then
  echo "lectures/04/labels.jsonl がありません。STEP 1 のラベル付けを 10 件目まで終えてください。"
  exit 1
fi
if ! git diff --quiet -- app/judge.py; then
  echo "app/judge.py に未 commit の変更があります。commit してから実行してください。"
  exit 1
fi
trap 'git restore app/judge.py' EXIT
mkdir -p "$RUNS"

# judge <名前> [追加の引数...]: 採点し、表示を <名前>.txt、結果を <名前>.json に残す
judge() {
  local name=$1; shift
  echo "===== $name ====="
  uv run python -m app.judge --wait "$WAIT" --out "$RUNS/$name.json" "$@" 2>&1 | tee "$RUNS/$name.txt"
  sleep 20
}

# STEP 1 の補足：講師のラベルとの比較（LLM は呼ばない）
uv run python -m app.judge --compare lectures/04/reference/labels_instructor.jsonl 2>&1 | tee "$RUNS/compare_instructor.txt"

# STEP 2：直す前の基準（lectures/04/rubric_before.md は、書き足す前の data/eval/rubric.md の写し）
judge step2_before --rubric lectures/04/rubric_before.md

# STEP 3：#05 の方針（用語集にないと伝えたうえでの一般的な説明は pass）を書き足した基準。揺れを見るため 2 回
judge step3_after_1
judge step3_after_2
cp "$RUNS/step3_after_1.json" lectures/04/judge_result.json

# 宿題（基礎）：判定の順序を「判定→理由」に入れ替える（CriterionVerdict の reason と verdict の行を入れ替える）
python3 - <<'EOF'
from pathlib import Path
p = Path("app/judge.py")
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
i = next(n for n, l in enumerate(lines) if l.strip().startswith("reason: str = Field("))
assert lines[i + 1].strip().startswith("verdict: Verdict = Field("), "入れ替える行が見つかりません"
lines[i], lines[i + 1] = lines[i + 1], lines[i]
p.write_text("".join(lines), encoding="utf-8")
EOF
git diff --quiet -- app/judge.py && { echo "判定の順序を入れ替えられませんでした"; exit 1; }
git diff -- app/judge.py | tee "$RUNS/homework_order.diff"
judge homework_verdict_first_1
judge homework_verdict_first_2

echo "完了: $RUNS に記録しました"
