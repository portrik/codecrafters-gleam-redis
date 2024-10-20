import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/regex
import gleam/string

import glisten.{type Message}

import configuration/configuration
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

fn parse_set_command(
  key: String,
  value: String,
  options: List(RESP),
) -> command.Command {
  let expiration =
    options
    |> list.fold(option.None, fn(folder, current) {
      case folder {
        option.None -> {
          case current {
            RESP(_length, "PX") -> option.Some(option.None)
            _ -> option.None
          }
        }
        option.Some(_) -> {
          case int.base_parse(current.data, 10) {
            Error(_) -> option.None
            Ok(value) -> option.Some(option.Some(value))
          }
        }
      }
    })
    |> option.flatten

  command.Set(key, value, expiration)
}

fn parse_config_get_command(key: String) -> Option(Command) {
  case string.lowercase(key) {
    "dir" -> option.Some(command.Config(command.ConfigRead, configuration.Dir))
    "dbfilename" ->
      option.Some(command.Config(command.ConfigRead, configuration.DBFilename))
    _ -> option.None
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
  // Commands should be case insensitive
  let resp_list =
    resp_list
    |> list.index_map(fn(value, index) {
      case index {
        index if index == 0 || index > 2 ->
          RESP(value.length, string.uppercase(value.data))
        _ -> value
      }
    })

  case resp_list {
    [RESP(_length, "PING")] -> option.Some(command.Ping)
    [RESP(_length, "ECHO"), RESP(_length, data)] ->
      option.Some(command.Echo(data))
    [RESP(_length, "GET"), RESP(_length, key)] -> option.Some(command.Get(key))
    [RESP(_length, "SET"), RESP(_length, key), RESP(_length, value), ..options] ->
      option.Some(parse_set_command(key, value, options))
    [RESP(_length, "CONFIG"), RESP(_length, "GET"), RESP(_length, key)] ->
      parse_config_get_command(key)
    _ -> option.None
  }
}
