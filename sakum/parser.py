from sakum import ast


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos]

    def advance(self):
        tok = self.tokens[self.pos]
        self.pos += 1
        return tok

    def check(self, *types):
        return self.peek().type in types

    def match(self, *types):
        if self.check(*types):
            return self.advance()
        return None

    def expect(self, type_):
        tok = self.peek()
        if tok.type != type_:
            raise SyntaxError(f"Expected {type_} but got {tok.type} ({tok.value}) at line {tok.line}")
        return self.advance()

    def parse(self):
        stmts = []
        while not self.check("EOF"):
            stmts.append(self.statement())
        return ast.Program(stmts)

    def statement(self):
        if self.match("LET"):
            return self.var_decl()
        if self.match("PRINT"):
            return self.print_stmt()
        if self.match("IF"):
            return self.if_stmt()
        if self.match("WHILE"):
            return self.while_stmt()
        if self.match("FOR"):
            return self.for_stmt()
        if self.match("FN"):
            return self.fn_stmt()
        if self.match("RETURN"):
            return self.return_stmt()
        if self.match("{"):
            return self.block()
        return self.expr_stmt()

    def var_decl(self):
        name = self.expect("IDENT").value
        value = None
        if self.match("="):
            value = self.expression()
        self.expect(";")
        return ast.VarDecl(name, value)

    def print_stmt(self):
        self.expect("(")
        value = self.expression()
        self.expect(")")
        self.expect(";")
        return ast.Print(value)

    def if_stmt(self):
        self.expect("(")
        cond = self.expression()
        self.expect(")")
        then = self.block()
        otherwise = None
        if self.match("ELSE"):
            otherwise = self.block()
        return ast.If(cond, then, otherwise)

    def while_stmt(self):
        self.expect("(")
        cond = self.expression()
        self.expect(")")
        body = self.block()
        return ast.While(cond, body)

    def for_stmt(self):
        self.expect("(")
        var = self.expect("IDENT").value
        self.expect(";")
        start = self.expression()
        self.expect(";")
        end = self.expression()
        self.expect(")")
        body = self.block()
        return ast.For(var, start, end, body)

    def fn_stmt(self):
        name = self.expect("IDENT").value
        self.expect("(")
        params = []
        if not self.check(")"):
            params.append(self.expect("IDENT").value)
            while self.match(","):
                params.append(self.expect("IDENT").value)
        self.expect(")")
        body = self.block()
        return ast.Function(name, params, body.statements)

    def return_stmt(self):
        value = None
        if not self.check(";"):
            value = self.expression()
        self.expect(";")
        return ast.Return(value)

    def block(self):
        self.expect("{")
        stmts = []
        while not self.check("}", "EOF"):
            stmts.append(self.statement())
        self.expect("}")
        return ast.Block(stmts)

    def expr_stmt(self):
        value = self.expression()
        self.expect(";")
        return ast.ExprStmt(value)

    def expression(self):
        return self.assignment()

    def assignment(self):
        expr = self.logic_or()
        if self.match("="):
            if isinstance(expr, ast.Variable):
                return ast.Assign(expr.name, self.expression())
            raise SyntaxError("Invalid assignment target")
        return expr

    def logic_or(self):
        left = self.logic_and()
        while self.match("OR"):
            right = self.logic_and()
            left = ast.Logical(left, "वा", right)
        return left

    def logic_and(self):
        left = self.equality()
        while self.match("AND"):
            right = self.equality()
            left = ast.Logical(left, "तथा", right)
        return left

    def equality(self):
        left = self.comparison()
        while self.match("==", "!="):
            op = self.tokens[self.pos - 1].value
            right = self.comparison()
            left = ast.Binary(left, op, right)
        return left

    def comparison(self):
        left = self.term()
        while self.match("<", ">", "<=", ">="):
            op = self.tokens[self.pos - 1].value
            right = self.term()
            left = ast.Binary(left, op, right)
        return left

    def term(self):
        left = self.factor()
        while self.match("+", "-"):
            op = self.tokens[self.pos - 1].value
            right = self.factor()
            left = ast.Binary(left, op, right)
        return left

    def factor(self):
        left = self.unary()
        while self.match("*", "/", "%"):
            op = self.tokens[self.pos - 1].value
            right = self.unary()
            left = ast.Binary(left, op, right)
        return left

    def unary(self):
        if self.match("-", "NOT"):
            op = self.tokens[self.pos - 1].value
            return ast.Unary(op, self.unary())
        return self.primary()

    def primary(self):
        tok = self.peek()
        if self.match("NUMBER", "STRING"):
            return ast.Literal(tok.value)
        if self.match("TRUE"):
            return ast.Literal(True)
        if self.match("FALSE"):
            return ast.Literal(False)
        if self.match("NULL"):
            return ast.Literal(None)
        if self.match("("):
            expr = self.expression()
            self.expect(")")
            return expr
        if self.match("IDENT"):
            name = tok.value
            if self.match("("):
                args = []
                if not self.check(")"):
                    args.append(self.expression())
                    while self.match(","):
                        args.append(self.expression())
                self.expect(")")
                return ast.Call(ast.Variable(name), args)
            return ast.Variable(name)
        raise SyntaxError(f"Unexpected token {tok.type} ({tok.value}) at line {tok.line}")
