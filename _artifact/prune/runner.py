"""ミュータントやバグ入りのコードに差し替えて pytest を回し、落ちたテストを集める。"""

import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = Path("shop/pricing.py")


def collect_tests():
    """pytest の並び順で全テストの nodeid を返す。"""
    out = subprocess.run(
        [sys.executable, "-m", "pytest", "--collect-only", "-q", "-p", "no:cacheprovider"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    return [line for line in out.splitlines() if "::" in line]


class Sandbox:
    """リポジトリを一時ディレクトリに写し、対象ファイルだけ差し替えたもの。"""

    def __init__(self, source):
        self.dir = Path(tempfile.mkdtemp(prefix="prune-"))
        for name in ("shop", "tests", "prune", "pytest.ini"):
            src = ROOT / name
            if src.is_dir():
                shutil.copytree(src, self.dir / name, ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy(src, self.dir / name)
        (self.dir / TARGET).write_text(source, encoding="utf-8")

    def failed(self, keep=None, deselect=None):
        """keep を渡すとそのテストだけ、deselect を渡すとそれを --deselect で外して回す。"""
        out = self.dir / "failed.txt"
        out.unlink(missing_ok=True)
        args = [sys.executable, "-m", "pytest", "-q", "-p", "no:cacheprovider",
                "-p", "prune.collect_plugin"]
        if keep is not None:
            args += list(keep)
        for nodeid in deselect or ():
            args += ["--deselect", nodeid]
        env = dict(os.environ, PRUNE_FAILED_OUT=str(out), PYTHONDONTWRITEBYTECODE="1")
        subprocess.run(args, cwd=self.dir, env=env, capture_output=True, text=True, timeout=60, check=False)
        if not out.exists():
            return set()
        return set(out.read_text(encoding="utf-8").split())

    def close(self):
        shutil.rmtree(self.dir, ignore_errors=True)


def run_all(sources, keep=None, deselect=None, workers=8):
    """{名前: ソース} の全部について、落ちたテストの集合を返す。"""

    def one(item):
        name, source = item
        box = Sandbox(source)
        try:
            return name, box.failed(keep=keep, deselect=deselect)
        finally:
            box.close()

    with ThreadPoolExecutor(max_workers=workers) as pool:
        return dict(pool.map(one, sources.items()))
