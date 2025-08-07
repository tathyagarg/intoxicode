# `http`
The HTTP module provides utilities for making HTTP requests and handling responses. It includes some functions to easily send requests and structures to represent HTTP objects.

## Functions

### `request_from_data`
Creates an HTTP request object from the given data. It takes the following parameters:
- `data` (string): A string representing the HTTP request data.
  - Example: `"GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"`

__*Returns:*__ An HTTP request object that can be used to send the request.

```intox
data = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
request = http ~ request_from_data(data)
```

### `make_request_data`
Is the reverse of `request_from_data`. It takes an HTTP request object and returns a string representation of the request data. This is useful for sending the request over a network. Parameters:
- `request` (object): An HTTP request object created by `request_from_data`.

__*Returns:*__ A string representing the HTTP request data.

```intox
request = http ~ Request{
  method -> http ~ GET,
  url -> "/",
  headers -> [
    http ~ Header{ name -> "Host", value -> "example.com" }
  ],
  body -> ""
}
data = http ~ make_request_data(request)
```

### `get`
Sends a GET request to the specified file descriptor.
- `fd` (integer): The file descriptor to which the request will be sent.
- `url` (string): The URL to which the GET request will be sent.
- `headers` (array of Header): A list of headers to include in the request.

__*Returns:*__ An HTTP response object containing the response data.

```intox
fd = 1  # Example file descriptor
url = "/"
headers = [
  http ~ Header{ name -> "Host", value -> "example.com" }
]
response = http ~ get(fd, url, headers)
```

### `post`
Sends a POST request to the specified file descriptor.
- `fd` (integer): The file descriptor to which the request will be sent.
- `url` (string): The URL to which the POST request will be sent.
- `headers` (array of Header): A list of headers to include in the request.
- `body` (string): The body of the POST request.

__*Returns:*__ An HTTP response object containing the response data.

```intox
fd = 1  # Example file descriptor
url = "/submit"
headers = [
  http ~ Header{ name -> "Host", value -> "example.com" },
  http ~ Header{ name -> "Content-Type", value -> "application/json" }
]
body = "{\"key\": \"value\"}"
response = http ~ post(fd, url, headers, body)
```

## Constants

<details>
  <summary><h3 style="display: inline-block">HTTP Methods</h3></summary>

  | Constant | Value | Description |
  |----------|-------|-------------|
  | `GET` | "GET" | Represents the HTTP GET method. |
  | `POST` | "POST" | Represents the HTTP POST method. |
  | `PUT` | "PUT" | Represents the HTTP PUT method. |
  | `DELETE` | "DELETE" | Represents the HTTP DELETE method. |
</details>

## Objects

### `Header`
Represents an HTTP header. It has the following fields:
- `name` (string): The name of the header.
- `value` (string): The value of the header.

### `Request`
Represents an HTTP request. It has the following fields:
- `method` (string): The HTTP method (e.g., "GET", "POST").
- `url` (string): The URL to which the request is being sent.
- `protocol` (string): The HTTP protocol version (e.g., "HTTP/1.1").
- `headers` (array of Header): A list of headers to include in the request.
- `body` (string): The body of the request, if applicable.

### `Response`
Represents an HTTP response. It has the following fields:
- `status_code` (integer): The HTTP status code of the response (e.g., 200, 404).
- `headers` (array of Header): A list of headers included in the response.
- `body` (string): The body of the response, containing the data returned by the server.


