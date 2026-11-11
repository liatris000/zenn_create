"""coverage.py の dynamic context で、テストごとに通った行を取る。"""

import subprocess
import sys
import tempfile
from pathlib import Path

from coverage import CoverageData

from prune.runner import ROOT, TARGET


def lines_by_test():
    with tempfile.TemporaryDirectory() as tmp:
        rc = Path(tmp) / "coveragerc"
        data_file = Path(tmp) / "coverage.dat"
        rc.write_text(f"[run]\nsource = shop\ndynamic_context = test_function\ndata_file = {data_file}\n")
        subprocess.run(
            [sys.executable, "-m", "coverage", "run", f"--rcfile={rc}", "-m", "pytest", "-q", "-p", "no:cacheprovider"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        data = CoverageData(basename=str(data_file))
        data.read()
        result = {}
        for lineno, contexts in data.contexts_by_lineno(str(ROOT / TARGET)).items():
            for ctx in contexts:
                if not ctx:
                    continue  # import 時に通った行(def や定数)はどのテストにも属さない
                # context は "test_bulk.test_bulk_5" の形(tests/ がパッケージでないので先頭に付かない)
                module, func = ctx.rsplit(".", 1)
                nodeid = f"tests/{module.split('.')[-1]}.py::{func}"
                result.setdefault(nodeid, set()).add(lineno)
        if not result:
            raise RuntimeError("テストごとの行が取れていない。dynamic_context の名前の形を確かめる")
        return result
