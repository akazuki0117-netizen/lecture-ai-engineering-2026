"""第1回: 素のLLMに質問するスクリプト。

使い方:
    uv run python -m app.ask "LoRAとは何ですか？"
    uv run python -m app.ask            # 質問を省略すると、講座に固有の質問をする
    uv run python -m app.ask --chat     # 会話履歴を保ったまま続けて質問する（第1回 宿題・実装）

ツールを持たない「素の」呼び出し。
講座に固有のことを聞くと、「分からない」と答えるか、一般論でもっともらしく答える
（講座の実際とは違う）ことを確かめよう。
（第3回で、用語集を検索できるエージェントにして改善する）
"""

import argparse

from google import genai
from google.genai import errors, types

from app.config import MODEL, api_error_message, get_api_key

# 講座に固有の質問。正しい答えは data/glossary.json の homework-levels にある
DEFAULT_QUESTION = "AIE2026の講座の宿題にある「3レベル」とは何ですか？"

# --chat モードで入力するとループを抜ける言葉
EXIT_WORDS = {"exit", "quit", "q", "終了"}


def format_usage(usage) -> str:
    """response.usage_metadata を「入力 / 出力」のトークン数の1行にする。"""
    if usage is None:
        return "[tokens] 取得できませんでした"
    line = f"[tokens] 入力 {usage.prompt_token_count} / 出力 {usage.candidates_token_count}"
    # 思考（thinking）するモデルは、回答とは別に思考トークンを使う
    if usage.thoughts_token_count:
        line += f" / 思考 {usage.thoughts_token_count}"
    return line


def ask(question: str) -> str:
    client = genai.Client(api_key=get_api_key())
    response = client.models.generate_content(model=MODEL, contents=question)

    # 第1回 演習: 入力トークン数と出力トークン数を表示する
    print(format_usage(response.usage_metadata))

    return response.text


class Conversation:
    """会話履歴を保ったまま、続けて質問する（第1回 宿題・実装）。

    LLM の API 自体は前の質問を覚えていない。そこで、これまでの
    質問（role="user"）と回答（role="model"）を履歴として持ち、
    毎回すべてを contents に入れて送る。
    """

    def __init__(self, client, model: str = MODEL):
        self.client = client
        self.model = model
        self.history: list[types.Content] = []

    def send(self, question: str) -> str:
        user = types.Content(role="user", parts=[types.Part(text=question)])
        response = self.client.models.generate_content(
            model=self.model, contents=[*self.history, user]
        )
        print(format_usage(response.usage_metadata))

        answer = response.text or ""
        # API エラーで例外になった場合はここに来ないので、失敗した質問は履歴に残らない
        self.history.append(user)
        self.history.append(types.Content(role="model", parts=[types.Part(text=answer)]))
        return answer


def chat_loop(conversation: Conversation, first_question: str | None = None) -> None:
    """標準入力から質問を読み、空行か exit で終わるまで会話を続ける。"""
    print("会話モード：空行または exit で終了します。\n")
    question = first_question
    while True:
        if question is None:
            try:
                question = input("あなた> ").strip()
            except EOFError:
                break
        if not question or question.lower() in EXIT_WORDS:
            break

        print(f"[質問] {question}")
        try:
            print(conversation.send(question))
        except errors.APIError as e:
            # レート制限などで失敗しても、それまでの会話は保ったまま続けられる
            print(api_error_message(e.code, e.message))
        print(f"[履歴] {len(conversation.history) // 2} 往復\n")
        question = None


def main() -> None:
    parser = argparse.ArgumentParser(description="素のLLMに質問する")
    parser.add_argument("question", nargs="?", default=None)
    parser.add_argument(
        "--chat", action="store_true", help="会話履歴を保ったまま続けて質問する"
    )
    args = parser.parse_args()

    print(f"[model] {MODEL}")
    if args.chat:
        client = genai.Client(api_key=get_api_key())
        chat_loop(Conversation(client), args.question)
        return

    question = args.question or DEFAULT_QUESTION
    print(f"[質問] {question}\n")
    try:
        print(ask(question))
    except errors.APIError as e:
        print(api_error_message(e.code, e.message))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
