"""pytest プラグイン。落ちたテストの nodeid を PRUNE_FAILED_OUT のファイルに 1 行ずつ書く。"""

import os


def pytest_runtest_logreport(report):
    if report.failed:
        out = os.environ.get("PRUNE_FAILED_OUT")
        if out:
            with open(out, "a", encoding="utf-8") as f:
                f.write(report.nodeid + "\n")
