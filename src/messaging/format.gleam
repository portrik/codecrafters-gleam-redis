import gleam/int
import gleam/string

pub fn format_to_resp_string(input: String) -> String {
  let length =
    input
    |> string.length
    |> int.to_string

  "$" <> length <> "\r\n" <> input <> "\r\n"
}
