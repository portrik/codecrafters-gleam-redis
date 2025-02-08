import birl
import birl/duration
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

import glisten.{type Message}

import configuration/configuration
import messaging/command.{type Command}

type RESP {
  RESP(length: Int, data: String)
}

fn bulk_regex_match_to_resp(match: regexp.Match) -> Result(RESP, Nil) {
  use #(length, data) <- result.try(case match {
    regexp.Match(_content, submatches: [option.Some(length), option.Some(data)]) ->
      Ok(#(length, data))
    _ -> Error(Nil)
  })

  use length <- result.try(
    length
    |> int.base_parse(10),
  )

  Ok(RESP(length: length, data: data))
}

fn parse_resp(message: String) -> Result(List(RESP), Nil) {
  use re <- result.try(
    "\\$(?<length>\\d+)\r\n(?<data>.*?)\r\n"
    |> regexp.from_string
    |> result.replace_error(Nil),
  )

  let matches =
    message
    |> regexp.scan(with: re, content: _)
    |> list.map(bulk_regex_match_to_resp)

  let all_matches_are_some =
    matches
    |> list.all(result.is_ok)

  case all_matches_are_some {
    False -> Error(Nil)
    True ->
      Ok(
        matches
        |> list.map(fn(value) {
          value
          |> result.unwrap(RESP(0, "UNKNOWN"))
          // The fallback should not be reachable with the all_matches_are_some check
        }),
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
            Ok(value) ->
              option.Some(
                option.Some(birl.add(birl.now(), duration.milli_seconds(value))),
              )
          }
        }
      }
    })
    |> option.flatten

  command.Set(key, value, expiration)
}

fn parse_config_get_command(key: String) -> Result(Command, Nil) {
  case string.lowercase(key) {
    "dir" -> Ok(command.Config(command.ConfigRead, configuration.Dir))
    "dbfilename" ->
      Ok(command.Config(command.ConfigRead, configuration.DBFilename))
    _ -> Error(Nil)
  }
}

fn parse_info_command(value: String) -> Result(Command, Nil) {
  case string.lowercase(value) {
    "replication" -> Ok(command.Info(command.Replication))
    _ -> Error(Nil)
  }
}

pub fn parse_bulk_message(message: Message(a)) -> Result(Command, Nil) {
  use message <- result.try(case message {
    glisten.Packet(content) ->
      content
      |> bit_array.to_string
      |> result.replace_error(Nil)
    _ -> Error(Nil)
  })

  use resp_list <- result.try(parse_resp(message))

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
    [RESP(_length, "PING")] -> Ok(command.Ping)
    [RESP(_length, "ECHO"), RESP(_length, data)] -> Ok(command.Echo(data))
    [RESP(_length, "GET"), RESP(_length, key)] -> Ok(command.Get(key))
    [RESP(_length, "SET"), RESP(_length, key), RESP(_length, value), ..options] ->
      Ok(parse_set_command(key, value, options))
    [RESP(_length, "CONFIG"), RESP(_length, "GET"), RESP(_length, key)] ->
      parse_config_get_command(key)
    [RESP(_length, "KEYS"), RESP(_length, pattern)] -> Ok(command.Keys(pattern))
    [RESP(_length, "INFO"), RESP(_length, value)] -> parse_info_command(value)
    [RESP(_length, "REPLCONF"), _, _] -> Ok(command.Echo("OK"))
    _ -> Error(Nil)
  }
}
