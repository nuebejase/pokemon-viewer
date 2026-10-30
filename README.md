# Pokémon Lookup (IT 126 – Module 3, Lesson 4)

A Flutter app that looks up a Pokémon by name from
`https://pokeapi.co/api/v2/pokemon/{name}` using the `http` package and
`dart:convert`.

## How requests are handled

- **Successful request (HTTP 200):** The body is decoded with `jsonDecode`,
  checked for the expected fields, and mapped into a `Pokemon` model. The name,
  ID, height, weight, abilities, types and sprite are displayed. A loading
  indicator shows while waiting, and the Search button is disabled so repeated
  submissions cannot start overlapping requests.
- **Unsuccessful response:** The status code is checked before the body is
  used. A 404 shows "Pokémon not found" with no retry, since repeating the same
  request cannot succeed. Other non-200 codes show a server error message with
  the code; retry is offered only for 5xx errors.
- **Network failures:** If no response arrives (offline, unreachable server, or
  a 12-second timeout), the app shows "No connection" or "Request timed out"
  and a "Try again" button.
- **Invalid data:** If a 200 response has malformed JSON or missing or
  wrongly typed fields, the app shows an error and displays none of the data.

## Proposed offline strategy

Each successfully retrieved Pokémon could be saved on the device (for example
with `shared_preferences` or a small SQLite database via `sqflite`, keyed by
name) together with the time it was fetched. When a request fails because of a
network error, the app would show the saved copy with a banner such as "Showing
saved data from <date> – may be outdated" and a Refresh button to retry when
connectivity returns. Pokémon that were never viewed would still show the error,
because there is nothing saved to display. This is not implemented in this
activity.