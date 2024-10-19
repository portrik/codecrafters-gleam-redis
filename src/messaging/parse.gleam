import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/regex

import glisten.{type Message}

import messaging/command.{type Command}

type RESP {
  RESP(length: Int, data: String)
}

fn bulk_regex_match_to_resp(match: regex.Match) -> Option(RESP) {
  let assert regex.Match(
    _content,
    submatches: [option.Some(length), option.Some(data)],
  ) = match

  let assert option.Some(length) =
    length
    |> int.base_parse(10)
    |> option.from_result

  option.Some(RESP(length: length, data: data))
}

fn parse_resp(message: String) -> Option(List(RESP)) {
  let assert option.Some(re) =
    "\\$(?<length>\\d+)\r\n(?<data>.*?)\r\n"
    |> regex.from_string
    |> option.from_result

  let matches =
    message
    |> regex.scan(with: re, content: _)
    |> list.map(bulk_regex_match_to_resp)

  let all_matches_are_some =
    matches
    |> list.all(option.is_some)

  case all_matches_are_some {
    False -> option.None
    True ->
      option.Some(
        matches
        |> list.map(fn(value) { option.unwrap(value, RESP(0, "UNKNOWN")) }),
        // The fallback should not be reachable with the check above
      )
  }
}

pub fn parse_bulk_message(message: Message(a)) -> Option(Command) {
  let assert option.Some(message) = case message {
    glisten.Packet(content) ->
      content
      |> bit_array.to_string
      |> option.from_result
    _ -> option.None
  }

  let assert option.Some(resp_list) = parse_resp(message)

  case resp_list {
    [RESP(_length, "PING")] -> option.Some(command.PING)
    [RESP(_length, "ECHO"), RESP(_length, data)] ->
      option.Some(command.ECHO(data))
    [RESP(_length, "GET"), RESP(_length, key)] -> option.Some(command.GET(key))
    [RESP(_length, "SET"), RESP(_length, key), RESP(_length, value)] ->
      option.Some(command.SET(key, value))
    _ -> option.None
  }
}
