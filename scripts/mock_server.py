#!/usr/bin/env python3
"""SPlayer-Next 外部 API 的本地模拟服务，用于在没有运行播放器时调试菜单栏歌词。

用法：
    python3 scripts/mock_server.py [--port 14558]

模拟内容：
    GET /api/info         应用信息
    GET /api/status       播放状态
    GET /api/now-playing  进度 + 当前曲目（App 轮询此接口）
    GET /api/lyrics       逐字歌词
    WS  /ws               hello / track / lyric / status 事件

歌词按 8 行 × 5 秒循环，位置随服务器启动时间推进。
"""

import argparse
import base64
import hashlib
import json
import math
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

LINES = [
    ("故事的小黄花", "The little yellow flower of the story"),
    ("从出生那年就飘着", "Has been floating since the year I was born"),
    ("童年的荡秋千", "The swing of my childhood"),
    ("随记忆一直晃到现在", "Keeps swinging with the memory until now"),
    ("吹着前奏望着天空", "Blowing the prelude, looking at the sky"),
    ("我想起花瓣试着掉落", "I think of petals trying to fall"),
    ("为你翘课的那一天", "The day I skipped class for you"),
    ("花落的那一天", "The day the flowers fell"),
]

LINE_DURATION = 5.0
LOOP_DURATION = LINE_DURATION * len(LINES)

START = time.time()


def now_ms() -> float:
    return time.time() * 1000


def position_ms() -> float:
    return (time.time() - START) % LOOP_DURATION * 1000


def build_lyrics():
    lines = []
    for index, (text, translation) in enumerate(LINES):
        start = index * LINE_DURATION * 1000
        end = start + LINE_DURATION * 1000
        # 按字符切分，给每个字一个时间片，模拟真实的逐字歌词
        chars = list(text)
        span = (end - start) / max(len(chars), 1)
        words = [
            {
                "word": char,
                "startTime": round(start + span * char_index),
                "endTime": round(start + span * (char_index + 1)),
            }
            for char_index, char in enumerate(chars)
        ]
        lines.append(
            {
                "words": words,
                "translatedLyric": translation,
                "romanLyric": "",
                "startTime": start,
                "endTime": end,
                "isBG": False,
                "isDuet": False,
            }
        )
    return lines


LYRICS = build_lyrics()

TRACK = {
    "id": "mock-track-1",
    "title": "晴天（模拟）",
    "artists": [{"name": "周杰伦"}],
    "duration": LOOP_DURATION * 1000,
}


def now_playing():
    pos = position_ms()
    return {
        "track": TRACK,
        "position": pos,
        "playing": True,
        "state": "playing",
        "speed": 1.0,
        "lyricOffsetMs": 0,
        "lyricAvailable": True,
        "lyricLineCount": len(LYRICS),
        "sendTimestamp": now_ms(),
    }


def ws_frame(payload: str) -> bytes:
    data = payload.encode("utf-8")
    length = len(data)
    if length < 126:
        header = bytes([0x81, length])
    elif length < 65536:
        header = bytes([0x81, 126]) + length.to_bytes(2, "big")
    else:
        header = bytes([0x81, 127]) + length.to_bytes(8, "big")
    return header + data


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # noqa: A003
        pass

    def send_json(self, payload, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/ws"):
            self.handle_ws()
            return
        if self.path.startswith("/api/info"):
            self.send_json({"name": "SPlayer-Next (mock)", "version": "1.0.0", "wsClients": 1})
        elif self.path.startswith("/api/status"):
            self.send_json(
                {
                    "state": "playing",
                    "position": position_ms(),
                    "duration": LOOP_DURATION * 1000,
                    "volume": 1,
                    "isFinished": False,
                    "currentIndex": 0,
                }
            )
        elif self.path.startswith("/api/now-playing"):
            self.send_json(now_playing())
        elif self.path.startswith("/api/lyrics"):
            self.send_json(
                {
                    "trackId": TRACK["id"],
                    "lyric": LYRICS,
                    "source": {"source": "online", "format": "lrc", "platform": "netease"},
                    "lyricOffsetMs": 0,
                }
            )
        else:
            self.send_json({"error": "not found"}, 404)

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", 0))
        if length:
            self.rfile.read(length)
        self.send_json({"ok": True})

    def handle_ws(self):
        key = self.headers.get("Sec-WebSocket-Key")
        if not key:
            self.send_json({"error": "WebSocket disabled"}, 403)
            return
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.wfile.flush()

        try:
            self.wfile.write(ws_frame(json.dumps({"kind": "hello", "clients": 1})))
            self.wfile.write(
                ws_frame(json.dumps({"kind": "event", "type": "track", "data": {"track": TRACK}}))
            )
            self.wfile.write(
                ws_frame(
                    json.dumps(
                        {
                            "kind": "event",
                            "type": "lyric",
                            "data": {
                                "source": {
                                    "source": "online",
                                    "format": "lrc",
                                    "platform": "netease",
                                },
                                "lyric": LYRICS,
                            },
                        },
                        ensure_ascii=False,
                    )
                )
            )
            while True:
                self.wfile.write(
                    ws_frame(
                        json.dumps(
                            {
                                "kind": "event",
                                "type": "status",
                                "data": {
                                    "state": "playing",
                                    "position": position_ms(),
                                    "duration": LOOP_DURATION * 1000,
                                    "volume": 1,
                                    "speed": 1.0,
                                    "isFinished": False,
                                },
                            }
                        )
                    )
                )
                self.wfile.flush()
                time.sleep(1.0)
        except (BrokenPipeError, ConnectionResetError):
            return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=14558)
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    print(f"mock SPlayer-Next 外部 API: http://127.0.0.1:{args.port}")
    print("按 Ctrl+C 停止")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
