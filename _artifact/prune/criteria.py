"""削除候補を出す 3 つの基準。"""


def _greedy(tests, items_of, owners_of, protected=frozenset()):
    remaining = set(tests)
    deleted = []
    for test in tests:
        if test in protected:
            continue
        covered_elsewhere = all((owners_of(item) & remaining) - {test} for item in items_of(test))
        if covered_elsewhere:
            remaining.discard(test)
            deleted.append(test)
    return deleted


def _invert(by_test):
    owners = {}
    for test, items in by_test.items():
        for item in items:
            owners.setdefault(item, set()).add(test)
    return owners


def by_coverage(tests, lines_by_test, protected=frozenset()):
    owners = _invert(lines_by_test)
    return _greedy(tests, lambda t: lines_by_test.get(t, set()), lambda i: owners[i], protected)


def by_mutants(tests, killed_by_mutant, protected=frozenset()):
    kills_by_test = {}
    for mid, failed in killed_by_mutant.items():
        for test in failed:
            kills_by_test.setdefault(test, set()).add(mid)
    return _greedy(tests, lambda t: kills_by_test.get(t, set()), lambda m: killed_by_mutant[m], protected)


def by_history(tests, failed_by_bug, protected=frozenset()):
    ever_failed = set().union(*failed_by_bug.values())
    return [t for t in tests if t not in ever_failed and t not in protected]
