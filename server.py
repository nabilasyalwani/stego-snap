from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from pathlib import Path
from io import BytesIO
import mimetypes
import RDHTurtleShell as rdh

app = FastAPI()

BASE_DIR = Path(__file__).resolve().parents[1]
UPLOADS_DIR = BASE_DIR / "uploads"
STEGO_DIR = BASE_DIR / "stego-images"
RECOVERED_DIR = BASE_DIR / "recovered-images"

for out_dir in (UPLOADS_DIR, STEGO_DIR, RECOVERED_DIR):
    out_dir.mkdir(parents=True, exist_ok=True)


class EncodeRequest(BaseModel):
    image_path: str
    secret_data: str


class DecodeRequest(BaseModel):
    stego_image_path: str


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/encode")
async def encode_endpoint(
    file: UploadFile = File(...),
    secret_data: str = Form(...),
):
    try:
        input_name = Path(file.filename).name
        input_path = UPLOADS_DIR / input_name
        input_path.write_bytes(await file.read())

        stego_path = await run_in_threadpool(
            rdh.encode_api,
            str(input_path),
            secret_data,
        )

        stego_file = Path(stego_path)

        if not stego_file.exists():
            raise HTTPException(
                status_code=500,
                detail="Encoded stego image not found",
            )

        file_bytes = stego_file.read_bytes()
        media_type = mimetypes.guess_type(stego_file.name)[0] or "application/octet-stream"

        return StreamingResponse(
            BytesIO(file_bytes),
            media_type=media_type,
            headers={
                "Content-Disposition": f'attachment; filename="{stego_file.name}"',
                "X-Filename": stego_file.name,
            },
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/decode")
async def decode_endpoint(file: UploadFile = File(...)):
    input_name = Path(file.filename).name
    input_path = UPLOADS_DIR / input_name
    input_path.write_bytes(await file.read())

    decoded_text = await run_in_threadpool(
        rdh.decode_api,
        str(input_path),
    )

    return {
        "ok": True,
        "decoded_text": decoded_text,
    }