# Flow Control
Intoxicode has 2 types of flow control: conditionals and loops. Conditionals allow you to execute different blocks of code based on certain conditions, while loops allow you to repeat a block of code multiple times.

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
Loops allow you to repeat a block of code multiple times. There are 2 types of loops in Intoxicode: `loop` loops (analogous to `while` loops in other languages) and `repeat` loops (somewhat like `for` loops in other languages).

### `loop` Loops
```intox
loop condition {
  ...
}.
```

### `repeat` Loops
```intox
repeat variable_name to count {
  ...
}.
```
