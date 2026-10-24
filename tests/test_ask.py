"""第1回 宿題（実装）：会話履歴のテスト。

FakeClient は実際のLLMを呼ばない偽クライアントで、送られてきた contents を記録する。
APIキーも利用枠も使わずに、「前の質問と回答が次のリクエストに入っているか」を確かめられる。
"""

from types import SimpleNamespace

import pytest
from google.genai import errors

from app.ask import Conversation, format_usage


def _usage(prompt=10, candidates=5, thoughts=None):
    return SimpleNamespace(
        prompt_token_count=prompt,
        candidates_token_count=candidates,
        thoughts_token_count=thoughts,
    )


class FakeModels:
    def __init__(self, answers):
        self.answers = list(answers)
        self.calls = []

    def generate_content(self, model, contents):
        self.calls.append(list(contents))
        answer = self.answers.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return SimpleNamespace(text=answer, usage_metadata=_usage())


class FakeClient:
    def __init__(self, answers):
        self.models = FakeModels(answers)


def _texts(contents):
    return [(c.role, c.parts[0].text) for c in contents]


def test_history_is_sent_with_next_question():
    client = FakeClient(["LoRAは低ランク適応です。", "QLoRAは量子化と組み合わせたものです。"])
    conv = Conversation(client, model="fake")

    assert conv.send("LoRAとは？") == "LoRAは低ランク適応です。"
    conv.send("それと似た手法は？")

    # 2回目のリクエストには、1回目の質問と回答が入っている
    assert _texts(client.models.calls[1]) == [
        ("user", "LoRAとは？"),
        ("model", "LoRAは低ランク適応です。"),
        ("user", "それと似た手法は？"),
    ]
    assert len(conv.history) == 4


def test_failed_request_is_not_added_to_history():
    error = errors.APIError(429, {"error": {"message": "rate limit"}})
    client = FakeClient(["一つ目の回答", error, "三つ目の回答"])
    conv = Conversation(client, model="fake")

    conv.send("一つ目")
    with pytest.raises(errors.APIError):
        conv.send("二つ目（失敗）")
    conv.send("三つ目")

    assert _texts(client.models.calls[2]) == [
        ("user", "一つ目"),
        ("model", "一つ目の回答"),
        ("user", "三つ目"),
    ]


def test_format_usage():
    assert format_usage(_usage(12, 34)) == "[tokens] 入力 12 / 出力 34"
    assert format_usage(_usage(12, 34, 56)) == "[tokens] 入力 12 / 出力 34 / 思考 56"
    assert "取得できません" in format_usage(None)
