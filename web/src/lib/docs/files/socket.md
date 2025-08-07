# `socket`
Sockets are a way to communicate between processes, either on the same machine or over a network. They provide a standard interface for sending and receiving data. Most of the basic socket functionality is provided by the `socket` module in Intoxicode.

## Functions

### `socket`
The `socket` function creates a new socket object. It takes three parameters:
- `domain` (integer): The address family, such as `AF_INET` for IPv4 or `AF_INET6` for IPv6.
- `type` (integer): The socket type, such as `SOCK_STREAM` for TCP or `SOCK_DGRAM` for UDP.
- `protocol` (integer): The protocol to be used with the socket, typically set to 0 to select the default protocol for the given type.

__*Returns*__: socket file descriptor.

```intox
fd = socket ~ socket(AF_INET, SOCK_STREAM, 0)
```

### `connect`
The `connect` function connects a socket to a remote address. It takes three parameters:
- `fd` (integer): The socket file descriptor returned by the `socket` function.
- `address` (string): A string representing the remote address, such as `"127.0.0.1"`
- `port` (integer): The port number to connect to.

```intox
socket ~ connect(fd, "127.0.0.1", 8080)
```

### `bind`
The `bind` function binds a socket to a local address and port. It takes three parameters:
- `fd` (integer): The socket file descriptor returned by the `socket` function.
- `address` (string): A string representing the local address, such as `"127.0.0.1"`
- `port` (integer): The port number to bind to.

```intox
socket ~ bind(fd, "127.0.0.1", 8080)
```

### `listen`
The `listen` function puts a socket into listening mode, allowing it to accept incoming connections. It takes two parameters:
- `fd` (integer): The socket file descriptor returned by the `socket` function.
- `backlog` (integer): The maximum number of queued connections. This is typically set to a small number like 5.

```intox
socket ~ listen(fd, 5)
```

### `accept`
The `accept` function accepts an incoming connection on a listening socket. It takes one parameter:
- `fd` (integer): The socket file descriptor returned by the `socket` function that is in listening mode.

__*Returns*__: A file descriptor for the accepted socket.

```intox
fd = socket ~ accept(listening_fd)
```

### `shutdown`
The `shutdown` function disables further send and/or receive operations on a socket. It takes two parameters:
- `fd` (integer): The socket file descriptor returned by the `socket` function.
- `how` (integer): An integer indicating how to shut down the socket. Refer to the section on [shutdown constants](#heading-constants) for valid values.

```intox
socket ~ shutdown(fd, socket ~ SHUT_SEND)
```

### `send`
The `send` function sends data over a socket. It takes three parameters:
- `fd` (integer): The socket file descriptor returned by the `socket` function.
- `data` (string): The data to be sent, typically a string.
- `flags` (integer): Optional flags to modify the behavior of the send operation. Refer to the section on [send flags](#heading-constants) for valid values. **Send flags though formally supported are not well implemented or documented yet.**

```intox
socket ~ send(fd, "Hello, World!", 0)
```

## Constants

<details>
<summary><h3 style="display: inline-block">Address Families</h3></summary>

| Constant | Value | Description |
|----------|-------|-------------|
| `AF_UNSPEC` | 0 | Unspecified address family |
| `AF_UNIX` | 1 | Local communication (Unix domain sockets) |
| `AF_INET` | 2 | IPv4 address family |
| `AF_AX25` | 3 | Amateur Radio AX.25 protocol |
| `AF_IPX` | 4 | IPX protocol |
| `AF_APPLETALK` | 5 | AppleTalk protocol |
| `AF_NETROM` | 6 | NET/ROM protocol |
| `AF_BRIDGE` | 7 | Ethernet Bridging |
| `AF_AAL5` | 8 | ATM AAL5 protocol |
| `AF_X25` | 9 | X.25 protocol |
| `AF_INET6` | 10 | IPv6 address family |
| `AF_MAX` | 12 | Maximum address family value |
</details>

<details>
<summary><h3 style="display: inline-block">Socket Types</h3></summary>

| Constant | Value | Description |
|----------|-------|-------------|
| `SOCK_STREAM` | 1 | Reliable, connection-oriented byte stream |
| `SOCK_DGRAM` | 2 | Connectionless, unreliable datagrams |
| `SOCK_RAW` | 3 | Raw socket for low-level access |
| `SOCK_RDM` | 4 | Reliable datagram socket |
| `SOCK_SEQPACKET` | 5 | Reliable, connection-oriented message stream |
| `SOCK_PACKET` | 6 | Packet socket for low-level access |
</details>

<details>
<summary><h3 style="display: inline-block">Shutdown Constants</h3></summary>

| Constant | Value | Description |
|----------|-------|-------------|
| `SHUT_RECV` | 0 | Disable further receive operations |
| `SHUT_SEND` | 1 | Disable further send operations |
| `SHUT_BOTH` | 2 | Disable both send and receive operations |
</details>
