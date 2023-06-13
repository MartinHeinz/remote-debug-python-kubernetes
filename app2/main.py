from fastapi import FastAPI

app = FastAPI()

@app.get("/api/test")
def test_api():
    return {"key": "some data"}
