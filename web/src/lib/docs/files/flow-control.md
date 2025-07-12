# Flow Control
There is only one way to control the flow of execution in Intoxicode: through conditionals. Loops are **not yet supported**, but are planned for future releases.

## Conditionals
Conditionals allow you to execute different blocks of code based on certain conditions. The syntax is about how you'd expect. There is one important thing to note, however: Intoxicode does not support `else if` statements. Instead, you can use multiple `if` statements in sequence.

### If Statements
```intox
if condition1 {
  ...
}.
```

Note the use of a certainty modifier at the end of the `if` block.

### If-Else Statements
```intox
if condition1 {
  ...
} else {
  ...
}.
```

Again, note the use of a certainty modifier at the end of the `else` blocks.

## Loops
Not supported (yet!)
