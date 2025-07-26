# Directives
Directives are a way to disable certain *esoteric* features of the lang. So, if for whatever reason, you wanted to actually use this lang, you can disable the features that make it esoteric.

The syntax of a directive is:
```intox
@directive_name.
```

## Available Directives
- `@uncertainty`: Disables the uncertainty feature, which allows for non-deterministic behavior in the language.
- `@repetition`: Disables the repetition feature, which allows for random lines to be repeated in the output.
- `@all`: Disables all esoteric features of the language, making it behave more like a traditional programming language.
- `@export`: Allows you to export functions from your program, making them available for use in other programs.
- `@import`: Allows you to import other files into your program, enabling modularity and code reuse.

## Important Note
When using the `@uncertainty` or `@all` directives, all lines become 100% certain. This eliminates the need for certainty modifiers. So, when you use either of those directives, you must omit any certainty modifiers in your code.

## Examples
### `@repetition`
```intox
@repetition.

scream("The program will not repeat any lines randomly for the whole program.").
```

### `@uncertainty`
```intox
@uncertainty

scream("The program will not have any uncertainty for the whole program.")
scream("Note the lack of certainty modifiers in this example.")
```

### `@all`
```intox
@all
scream("The program will behave like a traditional programming language.")
scream("No esoteric features will be present in this program.")
```

### `@export`
```intox
@all

fun greet(name) {
    scream("Hello, " + name + "!")
}

@export(greet)
```

Now, in this next example for `@import`, we will assume you have a file named `utils.intox` with the above content:

### `@import`
```intox
@all
@import("utils.??")

greet("World")
```
