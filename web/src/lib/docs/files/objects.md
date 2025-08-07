# Objects
Objects are the equivalent of structs in other languages like C.
They can be defined through the following syntax:

```intox
object ObjectName {
    field1 -> Type1,
    field2 -> Type2,
    ...
}
```

Example:
```intox
object Person {
    name -> string,
    age -> integer,
    email -> string
}
```

They can be initialized using the following syntax:

```intox
var = ObjectName {
    field1 -> value1,
    field2 -> value2,
    ...
}
```

Example:
```intox
person = Person {
    name -> "Alice",
    age -> 30,
    email -> "alice@intoxicode-is-awesome.com"
}
```
