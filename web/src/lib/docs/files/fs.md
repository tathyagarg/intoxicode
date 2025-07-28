# `fs`
All examples listed in this document are to be treated as continuations of the previous example, so you can run them in sequence.

## Functions

### `open`
Opens a file and returns the handle

Arguments:
1. `fname` (string): Name of the file
2. `mode` (number): Mode to open the file with. Refer to the subsequent sections on the open mode constants.

```intox
@all
@import("fs")

handle = (fs ~ open)("awesome.txt", (fs ~ READ) + (fs ~ WRITE))
scream(handle)
```

### `read`
Read a certain number of bytes from where the cursor currently is.

Arguments:
1. `handle` (number): File handle returned from `socket ~ open`
2. `buffer` (string): Buffer into which the read data will go
3. `buffer_size` (number): Number of bytes to read

```intox
buffer = ""
_ = (fs ~ read)(handle, buffer, 32)
scream(buffer)  # outputs first 32 bytes of the file
```

### `pread`
Read a certain number of bytes at an offset from where the cursor currently is.

Arguments:
1. `handle` (number): File handle returned from `socket ~ open`
2. `buffer` (string): Buffer into which the read data will go
3. `offset` (number): Number of bytes to skip
4. `buffer_size` (number): Number of bytes to read

```intox
_ = (fs ~ pread)(handle, buffer, 32, 16)
scream(buffer)  # ouputs 16 bytes starting from byte 33 of the file.
```

### `seek_to`
Moves the cursor to a specific position in the file.
Arguments:
1. `handle` (number): File handle returned from `socket ~ open`
2. `offset` (number): Number of bytes to skip

```intox
_ = (fs ~ seek_to)(handle, 16)
_ = (fs ~ read)(handle, buffer, 32)
scream(buffer)  # outputs first 32 bytes starting from byte 17 of the file
```

### `seek_by`
Moves the cursor by a certain number of bytes from the current position in the file.
Arguments:
1. `handle` (number): File handle returned from `socket ~ open`
2. `offset` (number): Number of bytes to skip

```intox
_ = (fs ~ seek_by)(handle, -10)
_ = (fs ~ read)(handle, buffer, 32)
scream(buffer)  # outputs first 32 bytes starting from byte 6 of the file
```
