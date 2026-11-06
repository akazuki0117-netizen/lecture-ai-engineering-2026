#!/usr/bin/env bash
# 第3回 演習・宿題（基礎）の実行記録を lectures/03/logs/ に残す。Codespaces で 1 回実行する。
# 使い方: bash lectures/03/compare.sh（commit 済みの状態で。約 5 分）
set -u
LOGS=lectures/03/logs
Q_COURSE="AIE2026の講座の宿題にある「3レベル」とは何ですか？"
Q_TERMS="LoRAとQLoRAの違いは？"
Q_QUIZ="第2回の内容から確認問題を1問出して"
REPEAT=3

if ! git diff --quiet -- app/agent.py app/tools.py; then
  echo "app/agent.py か app/tools.py に未 commit の変更があります。commit してから実行してください。"
  exit 1
fi
restore() { git restore app/agent.py app/tools.py; }
trap restore EXIT

# run <ログ名> <質問>: 同じ質問を REPEAT 回、--trace 付きで実行する（揺れを見るため）
run() {
  for i in $(seq 1 "$REPEAT"); do
    echo "===== $1 #$i: $2 ====="
    uv run python -m app.agent --trace "$2"
    sleep 20  # 無料枠のレート制限（毎分 15 リクエスト）に当たらないよう間をあける
  done 2>&1 | tee "$LOGS/$1.txt"
}

mkdir -p "$LOGS"
uv run pytest -q 2>&1 | tail -1 | tee "$LOGS/pytest.txt"
uv run python -m app.agent --list-tools | tee "$LOGS/list_tools.txt"

# 演習：元の指示のまま
run base_course "$Q_COURSE"
run base_terms "$Q_TERMS"
run base_quiz "$Q_QUIZ"

# 宿題 変更A：INSTRUCTIONS から「必ず search_glossary で用語集を確認する」の行を消す
sed -i '/必ず search_glossary で用語集を確認する/d' app/agent.py
git diff --quiet -- app/agent.py && { echo "変更Aが適用できませんでした"; exit 1; }
run changeA_course "$Q_COURSE"
run changeA_terms "$Q_TERMS"
restore

# 宿題 変更B：docstring の「1つだけ入れる」を「まとめて入れる」に変える
sed -i 's/query には調べたい用語を1つだけ入れる/query には調べたい用語をまとめて入れる/' app/tools.py
git diff --quiet -- app/tools.py && { echo "変更Bが適用できませんでした"; exit 1; }
run changeB_terms "$Q_TERMS"
restore

echo "完了: $LOGS に記録しました"
