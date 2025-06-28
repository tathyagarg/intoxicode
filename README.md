# Intoxicode
Run code like you're drunk!

## Features
1. Statements ending with `.` are certain, `?` are uncertain.
2. There's a 10% chance for each character in a string literal to switch case.
3. Variable names must include vowels, it's too hard to pronounce otherwise.
4. Operations can be performed with `+`, `-`, `*`, `/`, and `%` operators, but reliable answers are not guaranteed.
5. Functions can be defined with `fun` and called with `call`.
6. Comments can be added with `#` and will be ignored.
7. Exception prone code can be wrapped in `try` and `gotcha` blocks.
8. You can only have up to 25% of your code ending with `.` to keep it uncertain, given your code is at least 12 lines long. If exceeded, the certainty will be randomly decided for every line ending with `.` after the 25% is hit (i.e., if the first 4 lines of your code end with `.` and you have 16 lines, the first 4 lines execute as normal but if the 5th line ends with `.`, the `.` is ignored and a random certainty is assigned.
9. Any line can randomly be chosen to be skipped, simulating a drunken state.*
10. Any line can randomly be chosen to be repeated, simulating a drunken state.*
11. Information can be printed to the console with `scream` and information can be taken from stdin with `ask`.
12. Uncertain code can be wrapped in `maybe` blocks, which will execute the code inside with a 50% chance of success.
13. Uncertain code ending with `?` will execute with a 50% chance of success. This chance can be changed by specifying an expression containing the probability of success, e.g., `?75` for a 75% chance.

*: Given that the line is not an if statement, function definition, loop statement, or comment.
