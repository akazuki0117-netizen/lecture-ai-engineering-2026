# 第6回 解答

実行環境：GitHub Codespaces（`lec06` ブランチ）／使ったモデル：`gemini-3.5-flash-lite`（既定値）

実行ログ：[runs/](runs/)（[run_mcp.sh](run_mcp.sh) で、サーバーを 1 つずつ足しながら実行した記録）

## 演習

- STEP 1 のツールの名前：`glossary_search_glossary`（`app.mcp_agent`）。第5回までのエージェント（`app.agent`）は `search_materials` と `make_quiz`
- STEP 2 の [tool call]：`glossary_search_glossary({'query': '3レベル'})`
- STEP 3 の [tool call]：`fetch_fetch({'url': 'https://modelcontextprotocol.io/'})`
- STEP 4 の [tool call]：`aws_aws___search_documentation({'topics': ['general'], 'search_phrase': 'Amazon S3 versioning overview'})`
- 気づき・疑問：
  - 設定ファイルにサーバーを足すだけで、モデルに見えるツールは 1 個 → 2 個（fetch）→ 7 個（AWS）と増えた。どのサーバーを使うかは質問ごとにモデルが選び、STEP 2〜4 はどれも「モデル応答 2 回」（ツールを呼ぶ 1 回と、結果を読んで答える 1 回）だった。
  - AWS は 1 行足しただけで 5 個のツールが増え、`--list-tools` の表示は 1,801 文字から 8,938 文字になった。名前・説明文・引数は質問に関係なくモデルに渡るので、サーバーを足すほど入力が長くなる。第3回の「ツールの説明だけでコンテキストが埋まる」という話を、自分の表示で確かめられた。
  - fetch は、ページを取る前に `robots.txt` を取得していた。また、頼んだのは `https://modelcontextprotocol.io/` だったが、307 で転送され、実際に読んだのは `/docs/2026-07-28/getting-started/intro.md` だった。`[tool call]` の引数だけでは、実際に何を読んだかまでは分からない。
  - `fetch_fetch` の説明文には「以前はインターネットに接続できず断るよう言われていたが、このツールで接続できるようになった」という趣旨の、モデルへの働きかけが書かれていた。サーバーの作者の書いた文がそのままモデルに渡るので、足す前に説明文を読む必要があると思った。
  - `INSTRUCTIONS` には「回答の最後に、関係する回（第N回）を示す」とあるが、STEP 3・4 の回答には付かなかった。講座と関係のない質問なので自然だが、第4回の「回の表示」の基準なら不合格になる。

## 宿題

- 取り組んだレベル：基礎
- やったこと：
  - `app/mcp_server.py` に `server.tool()(tools.get_lecture_summary)` の 1 行を書き足し、用語集サーバーのツールをもう 1 つ公開した。演習の変更（`app/mcp_servers.json`）を commit してから書き足し、`git status` で、変更が `app/mcp_server.py` だけであることを確認した。`app/mcp_servers.json` と `app/mcp_agent.py` は変えていない。
  - 公開の前後で、同じ設定（glossary・fetch・aws）のまま「第2回では何を学びますか？」と質問して比べた。前後 2 回ずつの予定だったが、公開前の 2 回目はモデルの混雑（503）で取れず、公開前は 1 回だけになった。
- 結果：

  | | 公開前 | 公開後 1 回目 | 公開後 2 回目 |
  |---|---|---|---|
  | モデルに見えるツール | 7 個 | 8 個（`glossary_get_lecture_summary` が増えた） | 同左 |
  | [tool call] | `glossary_search_glossary({'query': '第2回'})` | `glossary_get_lecture_summary({'lecture': 2})` | `glossary_get_lecture_summary({'lecture': 2})` |
  | 回答の内容 | LoRA・QLoRA などの PEFT と、その演習 | 事前学習とファインチューニング、SFT、PEFT と LoRA、過学習、演習 | 左に加えて QLoRA との関係 |
  | 入力／出力トークン | 5,487 / 135 | 5,942 / 243 | 5,942 / 279 |
  | モデル応答 | 2 回 | 2 回 | 2 回 |

  - エージェント側を変えなくても、一覧にツールが増え、質問で呼ばれた。
  - `uv run pytest -q` は 26 passed。
- 気づき・疑問：
  - 公開前も「分からない」とは答えず、それらしい回答が返った。手元で確かめると、`search_glossary("第2回")` が返すのは、定義文に「第2回」と書かれている LoRA と QLoRA の 2 件だけだった。その 2 件だけを材料に「第2回では主に LoRA や QLoRA を学ぶ」とまとめていて、ファインチューニングが向く場面や SFT、過学習は抜けていた。間違いではないが、回答だけを見ても抜けに気づけない。合うツールが無いとき、エージェントは止まらずに、手持ちのツールで答えてしまうことがある。
  - `INSTRUCTIONS` には、公開前から「回の内容を聞かれたら get_lecture_summary を使う」と書かれていた。指示があっても、ツールが公開されていなければ使えない。指示とツールの一覧がずれていても、エラーにはならなかった。
  - 公開後の 2 回目の回答には「過学習、ハルシネーションへの対策を学びます」とあった。要点データでは、ハルシネーションは「関連用語」に名前があるだけで、対策を学ぶとは書かれていない。ツールが正しい内容を返しても、まとめるときにモデルが言い足すことがある。
  - サーバー側だけで機能を増やせるのは便利だが、逆に言えば、ほかの人のサーバーなら、こちらが何も変えなくても渡されるツールや説明文が変わりうる。fetch の版を固定するのは、そのためだと理解した。URL で接続する AWS のサーバーは版を固定していないので、ツールが変わっても気づきにくいのではないか、という点が気になった。
  - 実行スクリプトの作成には AI ツール（Claude Code）を使った。Codespaces での実行は自分で行い、結果はログで確かめた。
