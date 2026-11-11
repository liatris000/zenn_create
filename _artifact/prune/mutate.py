"""自作の小さなミューテーションテスト。

グループ A: 比較演算子・算術演算子の置き換え
グループ B: 整数定数の +1、and/or の入れ替え、not の除去、return の値を None に
"""

import ast
from dataclasses import dataclass

COMPARE_SWAP = {
    ast.Lt: ast.LtE, ast.LtE: ast.Lt, ast.Gt: ast.GtE, ast.GtE: ast.Gt, ast.Eq: ast.NotEq, ast.NotEq: ast.Eq,
}
BINOP_SWAP = {ast.Add: ast.Sub, ast.Sub: ast.Add, ast.Mult: ast.Add, ast.FloorDiv: ast.Mult}


@dataclass(frozen=True)
class Mutant:
    mid: str
    group: str
    line: int
    desc: str
    source: str


def _points(tree):
    """(group, node, 種類) を AST の走査順に返す。"""
    for node in ast.walk(tree):
        if isinstance(node, ast.Compare) and type(node.ops[0]) in COMPARE_SWAP:
            yield "A", node, "compare"
        elif isinstance(node, ast.BinOp) and type(node.op) in BINOP_SWAP:
            yield "A", node, "binop"
        elif isinstance(node, ast.Constant) and type(node.value) is int:
            yield "B", node, "const"
        elif isinstance(node, ast.BoolOp):
            yield "B", node, "boolop"
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            yield "B", node, "not"
        elif isinstance(node, ast.Return) and node.value is not None:
            yield "B", node, "return"


def _apply(tree, index):
    """index 番目の変異点だけを書き換えた新しいソースと説明を返す。"""
    _, node, kind = list(_points(tree))[index]
    before = ast.unparse(node)
    if kind == "compare":
        node.ops[0] = COMPARE_SWAP[type(node.ops[0])]()
    elif kind == "binop":
        node.op = BINOP_SWAP[type(node.op)]()
    elif kind == "const":
        node.value = node.value + 1
    elif kind == "boolop":
        node.op = ast.Or() if isinstance(node.op, ast.And) else ast.And()
    elif kind == "not":
        return _replace_not(tree, node), f"{before} -> {ast.unparse(node.operand)}"
    elif kind == "return":
        node.value = ast.Constant(None)
    return ast.unparse(tree), f"{before} -> {ast.unparse(node)}"


def _replace_not(tree, target):
    class Strip(ast.NodeTransformer):
        def visit_UnaryOp(self, node):
            if node is target:
                return node.operand
            return self.generic_visit(node)

    return ast.unparse(Strip().visit(tree))


def generate(source):
    """全ミュータントを、行・列の順に並べて A01, B01 … と番号を振って返す。"""
    points = list(_points(ast.parse(source)))
    order = sorted(range(len(points)), key=lambda i: (points[i][1].lineno, points[i][1].col_offset, i))
    mutants = []
    seq = {"A": 0, "B": 0}
    for i in order:
        tree = ast.parse(source)
        group, node, _ = list(_points(tree))[i]
        line = node.lineno
        new_source, desc = _apply(tree, i)
        seq[group] += 1
        mutants.append(Mutant(f"{group}{seq[group]:02d}", group, line, desc, new_source))
    return mutants
