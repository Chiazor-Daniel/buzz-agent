#!/usr/bin/env python3
"""
NVIDIA NIM Cloud Proxy
Local OpenAI-compatible endpoint that forwards to NVIDIA integrate API.
"""

import os
import json
import asyncio
from pathlib import Path
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse

API_KEY_PATH = Path.home() / ".config" / "nvidia" / "api.key"
PROXY_PORT = int(os.environ.get("NVIDIA_PROXY_PORT", "8888"))
NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1"

DEFAULT_MODELS = [
    {
        "id": "nvidia/nemotron-3.5-lightning-30b-a3b",
        "object": "model",
        "owned_by": "nvidia",
    },
    {
        "id": "meta/llama-3.1-70b-instruct",
        "object": "model",
        "owned_by": "meta",
    },
    {
        "id": "meta/llama-3.1-8b-instruct",
        "object": "model",
        "owned_by": "meta",
    },
    {
        "id": "mistralai/mistral-large-instruct-2407",
        "object": "model",
        "owned_by": "mistralai",
    },
    {
        "id": "mistralai/mixtral-8x22b-instruct-v0.1",
        "object": "model",
        "owned_by": "mistralai",
    },
]


def load_api_key():
    if not API_KEY_PATH.exists():
        raise RuntimeError(f"API key file not found: {API_KEY_PATH}")
    return API_KEY_PATH.read_text().strip()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.api_key = load_api_key()
    app.state.client = httpx.AsyncClient(timeout=300.0)
    yield
    await app.state.client.aclose()


app = FastAPI(title="NVIDIA NIM Cloud Proxy", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok", "backend": NVIDIA_BASE_URL}


@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": DEFAULT_MODELS,
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    if not body.get("model"):
        body["model"] = DEFAULT_MODELS[0]["id"]

    headers = {
        "Authorization": f"Bearer {request.app.state.api_key}",
        "Content-Type": "application/json",
    }

    is_streaming = body.get("stream", False)

    if is_streaming:
        async def stream_response():
            async with request.app.state.client.stream(
                "POST",
                f"{NVIDIA_BASE_URL}/chat/completions",
                headers=headers,
                json=body,
            ) as resp:
                if resp.status_code != 200:
                    text = await resp.aread()
                    yield f"data: {json.dumps({'error': text.decode()})}\n\n"
                    yield "data: [DONE]\n\n"
                    return
                async for chunk in resp.aiter_text():
                    if chunk:
                        yield chunk

        return StreamingResponse(
            stream_response(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
        )
    else:
        resp = await request.app.state.client.post(
            f"{NVIDIA_BASE_URL}/chat/completions",
            headers=headers,
            json=body,
        )
        try:
            data = resp.json()
        except Exception:
            data = {"error": resp.text}
        return JSONResponse(content=data, status_code=resp.status_code)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=PROXY_PORT, log_level="info")
