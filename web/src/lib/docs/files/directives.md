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

## Example
```intox
@all.
scream("Esoteric features have been disabled.").
scream("Now the language behaves more like a traditional programming language.").
```
