from flask import Flask, request, jsonify
import os, subprocess, uuid
from pathlib import Path

app = Flask(__name__)
BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / 'tmp'
MODEL_DIR = BASE_DIR / 'models'
UPLOAD_DIR.mkdir(exist_ok=True)
MODEL_DIR.mkdir(exist_ok=True)

INDEX_HTML = ''
try:
    INDEX_HTML = open('static/index.html', 'r', encoding='utf-8').read()
except Exception:
    INDEX_HTML = '<h1>Upload page missing</h1>'

@app.route('/')
def index():
    return INDEX_HTML

@app.route('/process', methods=['POST'])
def process():
    f = request.files.get('file')
    if not f:
        return jsonify({'error': 'no file uploaded'}), 400
    fname = f"{uuid.uuid4().hex}_{f.filename}"
    save_path = UPLOAD_DIR / fname
    f.save(save_path)

    # 1) Run py38 notebook (OCT) using papermill
    try:
        subprocess.check_call(['/opt/py38/bin/papermill', 'notebooks/OCT_Train_Val_Segmentation.ipynb', f'notebooks/out_oct_{fname}.ipynb', '-p', 'input_image', str(save_path)])
    except subprocess.CalledProcessError as e:
        return jsonify({'error': 'py38 notebook failed', 'detail': str(e)}), 500

    # 2) Run py37 notebook (pyradiomic)
    try:
        subprocess.check_call(['/opt/py37/bin/papermill', 'notebooks/pyradiomic.ipynb', f'notebooks/out_pyrad_{fname}.ipynb', '-p', 'input_image', str(save_path)])
    except subprocess.CalledProcessError as e:
        return jsonify({'error': 'py37 notebook failed', 'detail': str(e)}), 500

    # 3) Run R script (expects model.rds in models/)
    try:
        subprocess.check_call(['Rscript', 'r/run_R_from_txt.R', str(save_path), str(MODEL_DIR)])
    except subprocess.CalledProcessError as e:
        return jsonify({'error': 'R script failed', 'detail': str(e)}), 500

    return jsonify({
        'notebook_py38': f'notebooks/out_oct_{fname}.ipynb',
        'notebook_py37': f'notebooks/out_pyrad_{fname}.ipynb',
        'note': '请根据 notebooks 的输出定制返回结果，例如输出图片或 JSON 文件的路径'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
