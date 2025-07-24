# Array Built-in Functions
The following built-in functions are available for working with arrays in Intoxicode:

## `length`
The `length` function returns the length of a string or a list. It takes a single argument, which can be either a string or a list.
```intox
scream(length("Hello, World!")).
scream(length([1, 2, 3, 4, 5])).
```


## `append`
The `append` function appends one element to the end of a list. It takes two arguments: the list and the element to append.
Modifies the original list in place.
It does not return anything.
```intox
array = [1, 2, 3].
append(array, 4).
scream(array).
```

## `insert`
The `insert` function inserts an element at a specific index in a list. It takes three arguments: the list, the index, and the element to insert.
Modifies the original list in place.
It does not return anything.
```intox
array = [1, 2, 3].
insert(array, 1, 4).
scream(array).
```

## `remove`
The `remove` function removes an element from a list at a specific index. It takes two arguments: the list and the index of the element to remove.
Modifies the original list in place.
It does not return anything.
```intox
array = [1, 2, 3, 4, 5].
remove(array, 2).
scream(array).
```

## `update`
The `update` function updates an element at a specific index in a list. It takes three arguments: the list, the index, and the new value to set.
Modifies the original list in place.
It does not return anything.
```intox
array = [1, 2, 3].
update(array, 1, 4).
scream(array).
```

## `find_first`
The `find_first` function finds the first occurrence of an element in a list. It takes two arguments: the list and the element to find.
It returns the index of the first occurrence of the element, or -1 if the element is not found.
```intox
array = [1, 2, 3, 4, 5].
index = find_first(array, 3).
scream(index).  # Output: 2
```

## `find_last`
The `find_last` function finds the last occurrence of an element in a list. It takes two arguments: the list and the element to find.
It returns the index of the last occurrence of the element, or -1 if the element is not found.
```intox
array = [1, 2, 3, 4, 5, 3].
index = find_last(array, 3).
scream(index).  # Output: 5
```
