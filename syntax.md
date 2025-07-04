# Precedence Rules
- expression -> equality
- equality -> comparison ( ( "!=" | "==" ) comparison )
- comparison -> term ( ( "<" | ">" ) term )
- term -> factor ( ( "+" | "-" ) factor )
- factor -> primary ( ( "*" | "/" ) primary )
- primary -> identifier | literal | "(" expression ")"

