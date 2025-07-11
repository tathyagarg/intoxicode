# Statements
The fundamental differentiator of Intoxicode is its use of certainty modifiers to influence the execution of code. These modifiers can be applied to lines of code to increase the likelihood of a line being executed or skipped, allowing for a more controlled level of randomness. However, use of certainty modifiers to guarantee execution using a period is limited to 4 lines or 1/4 of the total lines in the program, whichever is greater. (*PS: Support for variable certainty modifiers is planned for a future release.*)

There are two cetainty modifiers in Intoxicode:
- **Period (.)**: This modifier guarantees that the line will be executed, but only if it is used in a limited manner. You can use it to guarantee execution of up to 4 lines or 1/4 of the total lines in the program, whichever is greater.

- **Question Mark (?)**: This modifier increases the likelihood of a line being executed, but does not guarantee it. It can be used to add an element of surprise to the program's output. A line with a question mark has a **75%** chance of being executed.

## Examples
Certainty modifiers are applied by ending the line with the modifier. For example:

```intox
scream("Hello, World!").
```
is a certain line that will always be executed at least once, while:

```intox
scream("Hello, World!")?
```
is a line that has a 75% chance of being executed.
