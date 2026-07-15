from dataclasses import dataclass, field


@dataclass
class Program:
    statements: list


@dataclass
class VarDecl:
    name: str
    value: object


@dataclass
class Print:
    value: object


@dataclass
class ExprStmt:
    value: object


@dataclass
class If:
    cond: object
    then: object
    otherwise: object


@dataclass
class While:
    cond: object
    body: object


@dataclass
class For:
    var: str
    start: object
    end: object
    body: object


@dataclass
class Function:
    name: str
    params: list
    body: list


@dataclass
class Return:
    value: object


@dataclass
class Block:
    statements: list


@dataclass
class Assign:
    name: str
    value: object


@dataclass
class Binary:
    left: object
    op: str
    right: object


@dataclass
class Unary:
    op: str
    right: object


@dataclass
class Logical:
    left: object
    op: str
    right: object


@dataclass
class Call:
    callee: object
    args: list


@dataclass
class Literal:
    value: object


@dataclass
class Variable:
    name: str
