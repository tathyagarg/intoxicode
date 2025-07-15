# Built-in Functions
There are a few builtin functions in Intoxicode. They are:

## `scream`
The `scream` function is used to output some data to the console. It can take any data type as an argument and will print it.
```intox
scream("Hello, World!\n").
```

## `abs`
The `abs` function returns the absolute value of a number. It can take an integer or a float as an argument.
```intox
scream(abs(-42)).
```

## `min`
The `min` function returns the minimum value from all the arguments provided. It can take any number of arguments, and they can be only numbers (integers or floats).
```intox
scream(min(3, 1, 4, 2)).
```

## `max`
The `max` function returns the maximum value from all the arguments provided. It can take any number of arguments, and they can be only numbers (integers or floats).
```intox
scream(max(3, 1, 4, 2)).
```

## `pow`
The `pow` function raises a number to the power of another number. It takes two arguments: the base and the exponent. Both arguments can be integers or floats.
```intox
scream(pow(2, 3)).
```

## `sqrt`
The `sqrt` function returns the square root of a number. It can take an integer or a float as an argument.
```intox
scream(sqrt(16)).
```

## `length`
The `length` function returns the length of a string or a list. It takes a single argument, which can be either a string or a list.
```intox
scream(length("Hello, World!")).
scream(length([1, 2, 3, 4, 5])).
```

## `to_string`
The `to_string` function converts a value to a string. It can take any data type as an argument and will return its string representation.
```intox
scream(to_string(42)).
```

## `to_number`
The `to_number` function converts a string to a number. It can take a string as an argument and will return its numeric representation. If the string cannot be converted to a number, it will return `null`.
```intox
scream(to_number("42")).
```

## `is_digit`
The `is_digit` function checks if a string contains only digits. It takes a single string argument and returns `true` if the string contains only digits, otherwise it returns `false`.
```intox
scream(is_digit("12345")).
scream(is_digit("123a45")).
```

## `chr`
The `chr` function converts an ASCII code to its corresponding character. It takes a single integer argument representing the ASCII code and returns the character as a string.
```intox
scream(chr(65)).  # Outputs "A"
```

More functions may be added in the future, and they will be documented here.
