# Functions
Functions are reusable blocks of code that can be called with a specific name. They can take parameters and return values.
The `fun` keyword is used to define a function. Functions can be called by their name followed by parentheses containing any arguments. The `throwaway` keyword is used inside a function to return a value.

## Function Definition
```intox
fun hello() {
  screm("Hello!").
}.
```

## Function Call
```intox
hello().
```

## Function with Parameters
```intox
fun greet(name) {
  scream("Hello ").
  scream(name).
}.
```

## Function with Return Value
```intox
fun add(a, b) {
  throwaway a + b.
}.
```

## Using Return Value
```intox
result = add(5, 10).
scream(result).
```
