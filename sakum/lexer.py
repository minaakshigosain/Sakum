import re


class Token:
    def __init__(self, type_, value, line):
        self.type = type_
        self.value = value
        self.line = line

    def __repr__(self):
        return f"Token({self.type}, {self.value!r})"


KEYWORDS = {
    "आरम्भ": "BEGIN", "नाम": "LET", "क्रिया": "FN", "यदि": "IF",
    "अन्यथा": "ELSE", "यावत्": "WHILE", "पर्यन्तम्": "FOR", "प्रत्यागम": "RETURN",
    "सत्य": "TRUE", "असत्य": "FALSE", "शून्य": "NULL", "लेख": "PRINT",
    "तथा": "AND", "वा": "OR", "न": "NOT",
    "begin": "BEGIN", "let": "LET", "fn": "FN", "if": "IF", "else": "ELSE",
    "while": "WHILE", "for": "FOR", "return": "RETURN", "true": "TRUE",
    "false": "FALSE", "null": "NULL", "print": "PRINT", "and": "AND",
    "or": "OR", "not": "NOT",
}

TOKEN_SPEC = [
    ("NUMBER", r"\d+(?:\.\d+)?"),
    ("STRING", r'"(?:[^"\\]|\\.)*"'),
    ("OP2", r"==|!=|<=|>="),
    ("OP1", r"[=+\-*/%<>(),.{};]"),
    ("IDENT", r"[ऀ-ॿa-zA-Z_][ऀ-ॿa-zA-Z0-9_]*"),
    ("SKIP", r"[ \t\r\n]+"),
    ("ERR", r"."),
]

MASTER = re.compile("|".join(f"(?P<{n}>{p})" for n, p in TOKEN_SPEC), re.UNICODE)


def tokenize(source):
    tokens = []
    line = 1
    pos = 0
    n = len(source)
    while pos < n:
        m = MASTER.match(source, pos)
        kind = m.lastgroup
        text = m.group()
        pos = m.end()
        if kind == "SKIP":
            line += text.count("\n")
            continue
        if kind == "NUMBER":
            tokens.append(Token("NUMBER", float(text) if "." in text else int(text), line))
        elif kind == "STRING":
            tokens.append(Token("STRING", text[1:-1], line))
        elif kind == "OP2":
            tokens.append(Token(text, text, line))
        elif kind == "OP1":
            tokens.append(Token(text, text, line))
        elif kind == "IDENT":
            tokens.append(Token(KEYWORDS.get(text, "IDENT"), text, line))
        else:
            raise SyntaxError(f"Unexpected character {text!r} at line {line}")
    tokens.append(Token("EOF", None, line))
    return tokens
