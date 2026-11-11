"""3 つの基準で削除候補を出し、実際に削ってからミュータントを回し直して比べる。

python -m prune.compare
"""

from prune import criteria
from prune.coverage_map import lines_by_test
from prune.guard import GUARD, PROTECTED
from prune.history import bug_sources
from prune.mutate import generate
from prune.runner import ROOT, TARGET, collect_tests, run_all


def killed(results):
    return {name for name, failed in results.items() if failed}


def main():
    source = (ROOT / TARGET).read_text(encoding="utf-8")
    tests = collect_tests()
    mutants = generate(source)
    group = {g: {m.mid: m.source for m in mutants if m.group == g} for g in ("A", "B")}
    desc = {m.mid: m.desc for m in mutants}

    full = {g: run_all(group[g]) for g in ("A", "B")}
    full_killed = {g: killed(full[g]) for g in ("A", "B")}
    print(f"テスト {len(tests)} 本 / ミュータント A {len(group['A'])} 個・B {len(group['B'])} 個")
    print(f"全テストで殺せた数: A {len(full_killed['A'])} / B {len(full_killed['B'])}")

    coverage = lines_by_test()
    history = run_all(bug_sources(source))
    print(f"失敗の履歴: バグ {len(history)} 件で、一度でも落ちたテスト {len(set().union(*history.values()))} 本")

    def candidates(protected):
        return {
            "カバレッジの重なり": criteria.by_coverage(tests, coverage, protected),
            "ミュータントの単独検出": criteria.by_mutants(tests, full["A"], protected),
            "失敗の履歴": criteria.by_history(tests, history, protected),
        }

    def measure(title, protected):
        print(f"\n## {title}")
        print("| 基準 | 削った本数 | 残り | 低下 A | 低下 B |")
        print("|---|---|---|---|---|")
        lost_by_name = {}
        for name, deleted in candidates(protected).items():
            keep = [t for t in tests if t not in deleted]
            after = {g: killed(run_all(group[g], keep=keep)) for g in ("A", "B")}
            lost = {g: sorted(full_killed[g] - after[g]) for g in ("A", "B")}
            lost_by_name[name] = (deleted, lost)
            print(f"| {name} | {len(deleted)} | {len(keep)} | {len(lost['A'])} | {len(lost['B'])} |")
        for name, (deleted, lost) in lost_by_name.items():
            print(f"\n[{name}] 取りこぼした B: " + (", ".join(f"{m}({desc[m]})" for m in lost["B"]) or "なし"))
            kept = [t.split("::")[1] for t in tests if t not in deleted]
            print(f"[{name}] 残したテスト: {', '.join(kept)}")

    measure("機械の基準だけ", frozenset())
    print(f"\n残す線: 規則 {len(GUARD)} つ・テスト {len(PROTECTED)} 本")
    measure("基準 + 残す線", PROTECTED)

    deleted = criteria.by_mutants(tests, full["A"])
    via_deselect = killed(run_all(group["A"], deselect=deleted))
    print(f"\n--deselect で外した場合のミュータント基準の低下 A: {len(full_killed['A'] - via_deselect)}")


if __name__ == "__main__":
    main()
