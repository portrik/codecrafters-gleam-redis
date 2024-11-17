import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string

import birl.{type Time}
import file_streams/file_stream.{type FileStream}

pub type ExpirationType {
  Seconds
  Milliseconds
}

fn parse_integer_big_endian(array: BitArray) -> Result(Int, Nil) {
  array
  |> bit_array.base16_encode
  |> string.to_graphemes
  |> list.sized_chunk(2)
  |> list.reverse
  |> list.map(string.concat)
  |> string.concat
  |> int.base_parse(16)
}

fn parse_integer_little_endian(array: BitArray) -> Result(Int, Nil) {
  array
  |> bit_array.base16_encode
  |> int.base_parse(16)
}

fn parse_value(stream: FileStream, size: BitArray) -> Result(String, Nil) {
  case size {
    <<192>> | <<193>> | <<194>> -> {
      let size = case size {
        <<192>> -> 1
        <<193>> -> 2
        <<194>> -> 4
        _ -> panic as "Unreachable code reached"
      }

      use value <- result.try(
        stream
        |> file_stream.read_bytes_exact(size)
        |> result.map(parse_integer_little_endian)
        |> result.nil_error
        |> result.flatten,
      )

      Ok(int.to_string(value))
    }
    <<195>> -> panic as "LZF compression is not supported"
    size -> {
      use size <- result.try(
        size
        |> bit_array.base16_encode
        |> int.base_parse(16),
      )

      use value <- result.try(
        stream
        |> file_stream.read_bytes_exact(size)
        |> result.map(fn(value) { bit_array.to_string(value) })
        |> result.nil_error
        |> result.flatten,
      )

      Ok(value)
    }
  }
}

pub fn parse_key_value_pair(
  stream: FileStream,
  key_size: BitArray,
) -> Result(#(String, String), Nil) {
  use key <- result.try(parse_value(stream, key_size))

  use value_size <- result.try(
    stream
    |> file_stream.read_bytes_exact(1)
    |> result.nil_error,
  )

  use value <- result.try(parse_value(stream, value_size))

  Ok(#(key, value))
}

pub fn parse_expiration(
  stream: FileStream,
  expiration_type: ExpirationType,
) -> Result(Time, Nil) {
  case expiration_type {
    Seconds -> {
      use seconds <- result.try(
        stream
        |> file_stream.read_bytes_exact(4)
        |> result.map(parse_integer_big_endian)
        |> result.nil_error
        |> result.flatten,
      )

      Ok(birl.from_unix(seconds))
    }
    Milliseconds -> {
      use milliseconds <- result.try(
        stream
        |> file_stream.read_bytes_exact(8)
        |> result.map(parse_integer_big_endian)
        |> result.nil_error
        |> result.flatten,
      )

      Ok(birl.from_unix(milliseconds / 1000))
    }
  }
}
