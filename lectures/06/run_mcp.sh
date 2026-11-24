#!/usr/bin/env bash
# 第6回 演習（STEP 1〜4）と宿題（基礎）をまとめて実行し、lectures/06/runs/ に残す。
# 使い方: bash lectures/06/run_mcp.sh（Codespaces で。約 8 分。途中で止まっても、再実行すると失敗した分だけ取り直す）
# 設定とサーバーを段階ごとに切り替えながら実行し、終わったら commit 済みの状態に戻す。
set -u
RUNS=lectures/06/runs
CONFIG=app/mcp_servers.json
SERVER=app/mcp_server.py
TRIES=4
Q_COURSE='AIE2026の講座の宿題にある「3レベル」とは何ですか？'
Q_FETCH='https://modelcontextprotocol.io/ の冒頭を日本語で3行に要約して'
Q_AWS='AWSのドキュメントを検索して、Amazon S3 のバージョニングを2行で説明して'
Q_LECTURE='第2回では何を学びますか？'

if ! git diff --quiet -- app; then
  echo "app/ に未 commit の変更があります。commit してから実行してください。"
  exit 1
fi
restore() { git restore "$CONFIG" "$SERVER"; }
trap restore EXIT
mkdir -p "$RUNS"

failed() { grep -qE "混み合っています|レート制限に達し|接続できませんでした|Traceback" "$1"; }
# record <名前> <コマンド...>: 実行して <名前>.txt に残す。混雑などで失敗したら 60 秒待って取り直す
record() {
  local name=$1 file="$RUNS/$1.txt"; shift
  if [ -f "$file" ] && ! failed "$file"; then echo "（$name は記録済み）"; return; fi
  for i in $(seq 1 "$TRIES"); do
    echo "===== $name（$i 回目）: $* ====="
    "$@" 2>&1 | tee "$file"
    failed "$file" || break
    [ "$i" -lt "$TRIES" ] && sleep 60
  done
}
ask() { record "$1" uv run python -m app.mcp_agent --trace "$2"; sleep 15; }
tools() { record "$1" uv run python -m app.mcp_agent --list-tools; }
# use_servers <名前...>: 設定ファイルを、指定したサーバーだけにする
use_servers() {
  git restore "$CONFIG"
  python3 - "$CONFIG" "$@" <<'PY'
import json, sys
path, names = sys.argv[1], sys.argv[2:]
servers = json.load(open(path, encoding="utf-8"))["mcpServers"]
json.dump({"mcpServers": {n: servers[n] for n in names}}, open(path, "w", encoding="utf-8"), indent=2)
PY
}

# ---- 演習：get_lecture_summary を公開する前のサーバーで行う ----
sed -i '/^server.tool()(tools.get_lecture_summary)/d' "$SERVER"
git diff --quiet -- "$SERVER" && { echo "公開前のサーバーに戻せませんでした"; exit 1; }
use_servers glossary
record step1_agent_tools uv run python -m app.agent --list-tools
tools step1_mcp_tools
ask step2_glossary "$Q_COURSE"
use_servers glossary fetch
tools step3_tools
ask step3_fetch "$Q_FETCH"
use_servers glossary fetch aws
tools step4_tools
ask step4_aws "$Q_AWS"

# ---- 宿題（基礎）：サーバー側だけを変え、エージェント側（設定とコード）は変えずに比べる ----
use_servers glossary fetch aws
tools hw_before_tools
ask hw_before_1 "$Q_LECTURE"
ask hw_before_2 "$Q_LECTURE"
git restore "$SERVER"
tools hw_after_tools
ask hw_after_1 "$Q_LECTURE"
ask hw_after_2 "$Q_LECTURE"

restore
record pytest uv run pytest -q
echo "--- 失敗のまま残っている記録（空なら全部そろいました）"
for f in "$RUNS"/*.txt; do failed "$f" && echo "$f"; done
true
