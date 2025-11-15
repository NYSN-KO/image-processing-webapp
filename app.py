from flask import Flask, request, send_file, send_from_directory, jsonify
from pathlib import Path
import uuid, os, subprocess, zipfile, shutil
BASE = Path(__file__).resolve().parent
UPLOAD_DIR = BASE / 'tmp'
RESULTS_DIR = BASE / 'results'
SCRIPTS_DIR = BASE / 'scripts'
MODEL_DIR = BASE / 'models'
UPLOAD_DIR.mkdir(exist_ok=True)
RESULTS_DIR.mkdir(exist_ok=True)
app = Flask(__name__)
def run_cmd(cmd, cwd=None):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=cwd, check=True)
        return 0, r.stdout
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout or str(e)
@app.route('/', methods=['GET'])
def index():
    return send_from_directory('static', 'index.html')
@app.route('/process', methods=['POST'])
def process():
    f = request.files.get('file')
    if not f:
        return jsonify({'error':'no file uploaded'}), 400
    job = uuid.uuid4().hex[:8]
    job_dir = RESULTS_DIR / job
    job_dir.mkdir(parents=True, exist_ok=True)
    saved = UPLOAD_DIR / f'{job}_{f.filename}'
    f.save(str(saved))
    logs = {}
    # py38
    cmd1 = [str(SCRIPTS_DIR/'run_py38_notebook.sh'), str(saved), str(job_dir)]
    rc, out = run_cmd(cmd1, cwd=str(BASE))
    logs['py38'] = {'rc':rc, 'out':out}
    with open(job_dir/'step_py38.log','w',encoding='utf-8') as w: w.write(out)
    if rc != 0:
        return jsonify({'error':'py38 failed','log':out}), 500
    # py37
    cmd2 = [str(SCRIPTS_DIR/'run_py37_notebook.sh'), str(saved), str(job_dir)]
    rc, out = run_cmd(cmd2, cwd=str(BASE))
    logs['py37'] = {'rc':rc, 'out':out}
    with open(job_dir/'step_py37.log','w',encoding='utf-8') as w: w.write(out)
    if rc != 0:
        return jsonify({'error':'py37 failed','log':out}), 500
    # R
    cmd3 = [str(SCRIPTS_DIR/'run_r.sh'), str(saved), str(MODEL_DIR), str(job_dir)]
    rc, out = run_cmd(cmd3, cwd=str(BASE))
    logs['R'] = {'rc':rc, 'out':out}
    with open(job_dir/'step_R.log','w',encoding='utf-8') as w: w.write(out)
    if rc != 0:
        return jsonify({'error':'R failed','log':out}), 500
    # zip results
    zip_path = RESULTS_DIR / f'{job}.zip'
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for root,_,files in os.walk(job_dir):
            for fn in files:
                full = os.path.join(root, fn)
                arc = os.path.relpath(full, job_dir)
                z.write(full, arc)
    return send_file(str(zip_path), as_attachment=True, download_name=f'{job}.zip')
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
