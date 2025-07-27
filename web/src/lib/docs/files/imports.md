# Imports and Modules
Imports and modules allow for code organization and reuse. In Intoxicode, they're facilitated through the `@import` and `@export` directives.

## Importing Modules
To import a file, use the `@import` directive followed by the file path. The path can be relative or absolute, and it should point to a `.??` file.

```intox
@import("awesome.??")
```

However, this only works for single files. To import entire modules, use the `@import` directive with a module name. The exports from the module's `huh.??` file will be available in the current file.

```intox
@import("awesome")
```

## Exporting
To make functions available to other files, use the `@export` directive. This directive should be placed after the function definition.

```intox
fun add(a, b) {
    throwaway a + b
}

fun subtract(a, b) {
    throwaway a - b
}

@export(add subtract)
```

Notice how there are no commas between the function names in the `@export` directive. This is because Intoxicode uses whitespace to separate arguments in directives.
