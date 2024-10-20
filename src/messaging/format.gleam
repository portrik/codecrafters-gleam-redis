import gleam/int
import gleam/list
import gleam/string

import configuration/configuration.{type ConfigurationKey}

pub fn format_to_resp_string(input: String) -> String {
  let length =
    input
    |> string.length
    |> int.to_string

  "$" <> length <> "\r\n" <> input <> "\r\n"
}

pub fn format_to_resp_array(input: List(String)) -> String {
  let length =
    input
    |> list.length
    |> int.to_string

  let content =
    input
    |> list.map(format_to_resp_string)
    |> string.join("")

  "*" <> length <> "\r\n" <> content
}

pub fn configuration_key_to_string(key: ConfigurationKey) -> String {
  case key {
    configuration.Dir -> "dir"
    configuration.DBFilename -> "dbfilename"
  }
}
