# Arrays
As shown in the previous section, arrays are a collection of elements. Unlike in most languages, arrays in Intoxicode can store multiple data types. This does kind of defeats the purpose of arrays, but it is useful in some cases. For example, you can store a string and an integer in the same array. (Yes, I know, this is really a list but we call it an array for some reason.)

## Creating an Array
```intox
array = [1, "Hello", 3.14, true].
```

## Accessing Elements
To access elements in an array, you can use the index of the element. The index starts at 0, so the first element is at index 0, the second at index 1, and so on.

```intox
array = [1, "Hello", 3.14, true].
scream(array[0]).
```

## Modifying Elements
You can use the built-in `update` function to modify elements in an array. The `update` function takes the array, the index of the element to modify, and the new value.

```intox
array = [1, "Hello", 3.14, true].
update(array, 1, "World").
scream(array[1]).
```

## Adding Elements
To add elements to an array, you can use the `append` function. This function takes the array and the value to add.

```intox
array = [1, "Hello", 3.14, true].
append(array, "New Element").
scream(array[4]).
```

## Removing Elements
To remove elements from an array, you can use the `remove` function. This function takes the array and the index of the element to remove.

```intox
array = [1, "Hello", 3.14, true].
remove(array, 2).
scream(array[2]).  # This will now print 'true' since the element at index 2 was removed.
```

