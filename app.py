# new app.py — save uploaded file, create job dir, call scripts, zip results and return
import os
import uuid
import shutil
import zipfile
import subprocess
from pathlib import Path
from flask import Flask, request, jsonify, send_file

app = Flask(__name__)
BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "tmp"
RESULTS_DIR = BASE_DIR / "results"
SCRIPTS_DIR = BASE_DIR / "scripts"
MODEL_DIR = BASE_DIR / "models"   # contains best_model.pth and model.rds

UPLOAD_DIR.mkdir(exist_ok=True)
RESULTS_DIR.mkdir(exist_ok=True)

def run_cmd(cmd, cwd=None, env=None):
    """
    Run subprocess, return (returncode, stdout+stderr)
    """
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=cwd, env=env, check=True)
        return 0, r.stdout
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout or str(e)

@app.route("/", methods=["GET"])
def index():
    return "OCT pipeline API. POST image to /process"

@app.route("/process", methods=["POST"])
def process():
    """
    Form-data: file=<image file>, optional job_name=<string>
    Returns: zip file of results (attachment)
    """
    f = request.files.get("file")
    if not f:
        return jsonify({"error": "no file uploaded (field name 'file')"}), 400

    job_name = request.form.get("job_name") or uuid.uuid4().hex[:8]
    job_dir = RESULTS_DIR / job_name
    if job_dir.exists():
        # avoid clobbering
        job_dir = RESULTS_DIR / f"{job_name}_{uuid.uuid4().hex[:6]}"
    job_dir.mkdir(parents=True, exist_ok=True)

    # save upload
    filename = f.filename or "input.png"
    saved = UPLOAD_DIR / f"{job_name}_{filename}"
    f.save(saved)

    logs = {}
    # 1) Run py38 notebook (OCT) -> script: run_py38_notebook.sh <input> <out_dir>
    cmd1 = [str(SCRIPTS_DIR / "run_py38_notebook.sh"), str(saved), str(job_dir)]
    rc, out = run_cmd(cmd1, cwd=str(BASE_DIR))
    logs['py38'] = {"rc": rc, "out": out}
    if rc != 0:
        # save log and return error with the log
        with open(job_dir / "step_py38.log", "w", encoding="utf-8") as w: w.write(out)
        return jsonify({"error": "py38 step failed", "log": out}), 500
    with open(job_dir / "step_py38.log", "w", encoding="utf-8") as w: w.write(out)

    # 2) Run py37 notebook (pyradiomic) -> script: run_py37_notebook.sh <input> <out_dir>
    cmd2 = [str(SCRIPTS_DIR / "run_py37_notebook.sh"), str(saved), str(job_dir)]
    rc, out = run_cmd(cmd2, cwd=str(BASE_DIR))
    logs['py37'] = {"rc": rc, "out": out}
    if rc != 0:
        with open(job_dir / "step_py37.log", "w", encoding="utf-8") as w: w.write(out)
        return jsonify({"error": "py37 step failed", "log": out}), 500
    with open(job_dir / "step_py37.log", "w", encoding="utf-8") as w: w.write(out)

    # 3) Run R step -> run_r.sh <input> <model_dir> <out_dir>
    cmd3 = [str(SCRIPTS_DIR / "run_r.sh"), str(saved), str(MODEL_DIR), str(job_dir)]
    rc, out = run_cmd(cmd3, cwd=str(BASE_DIR))
    logs['R'] = {"rc": rc, "out": out}
    with open(job_dir / "step_R.log", "w", encoding="utf-8") as w: w.write(out)
    if rc != 0:
        return jsonify({"error": "R step failed", "log": out}), 500

    # create zip
    zip_path = RESULTS_DIR / f"{job_name}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(job_dir):
            for fn in files:
                full = os.path.join(root, fn)
                arcname = os.path.relpath(full, job_dir)
                z.write(full, arcname)

    # return zip as attachment
    return send_file(str(zip_path), as_attachment=True, download_name=f"{job_name}.zip")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
