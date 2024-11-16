import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import store/parse

import file_streams/file_stream.{type FileStream}

import store/store.{type Record}

pub type DatabaseFileError {
  DatabaseFileCannotBeFound
  DatabaseFileInvalidMagicString
  DatabaseFileInvalidMetadata
  DatabaseFileInvalidData
  DatabaseFileChecksumError
}

pub fn load_database_file(
  filename: String,
) -> Result(Dict(String, Record), DatabaseFileError) {
  use stream <- result.try(
    filename
    |> file_stream.open_read
    |> result.replace_error(DatabaseFileCannotBeFound),
  )

  use stream <- result.try(validate_magic_string(stream))
  use #(stream, _meta_data) <- result.try(read_metadata(stream, list.new()))
  use records <- result.try(read_data(stream))
  use #(_stream, _check_sum) <- result.try(read_check_sum(stream))

  Ok(records)
}

fn read_byte(
  stream: FileStream,
  error: DatabaseFileError,
) -> Result(BitArray, DatabaseFileError) {
  stream
  |> file_stream.read_bytes_exact(1)
  |> result.replace_error(error)
}

fn validate_magic_string(
  stream: FileStream,
) -> Result(FileStream, DatabaseFileError) {
  use header_bytes <- result.try(
    stream
    |> file_stream.read_bytes_exact(9)
    |> result.replace_error(DatabaseFileInvalidMagicString),
  )

  use header <- result.try(
    header_bytes
    |> bit_array.to_string
    |> result.replace_error(DatabaseFileInvalidMagicString),
  )

  case header {
    "REDIS" <> version_number ->
      version_number
      |> int.base_parse(10)
      |> result.replace_error(DatabaseFileInvalidMagicString)
    _ -> Error(DatabaseFileInvalidMagicString)
  }
  |> result.replace(stream)
}

fn read_metadata(
  stream: FileStream,
  meta_data: List(#(String, String)),
) -> Result(#(FileStream, List(#(String, String))), DatabaseFileError) {
  use current_byte <- result.try(read_byte(stream, DatabaseFileInvalidMetadata))

  case current_byte {
    <<254>> -> Ok(#(stream, meta_data))
    <<250>> -> read_metadata(stream, meta_data)
    current_byte -> {
      use header <- result.try(
        stream
        |> parse.parse_key_value_pair(current_byte)
        |> result.replace_error(DatabaseFileInvalidMetadata),
      )

      stream
      |> read_metadata(list.append(meta_data, [header]))
    }
  }
}

fn recursive_data_read(
  stream: FileStream,
  records: Dict(String, Record),
) -> Result(Dict(String, Record), DatabaseFileError) {
  use current_byte <- result.try(read_byte(stream, DatabaseFileInvalidData))

  case current_byte {
    <<255>> -> Ok(records)
    current_byte -> {
      let expiration = case current_byte {
        <<252>> ->
          parse.parse_expiration(stream, parse.Milliseconds)
          |> option.from_result
        <<253>> ->
          parse.parse_expiration(stream, parse.Seconds)
          |> option.from_result
        _ -> option.None
      }

      use _value_type_byte <- result.try(case expiration {
        option.None -> Ok(current_byte)
        option.Some(_) -> {
          read_byte(stream, DatabaseFileInvalidData)
        }
      })

      use size_byte <- result.try(read_byte(stream, DatabaseFileInvalidData))

      use #(key, value) <- result.try(
        stream
        |> parse.parse_key_value_pair(size_byte)
        |> result.replace_error(DatabaseFileInvalidData),
      )

      stream
      |> recursive_data_read(
        records
        |> dict.insert(key, store.Record(value, expiration)),
      )
    }
  }
}

fn read_data(
  stream: FileStream,
) -> Result(Dict(String, Record), DatabaseFileError) {
  use _index_byte <- result.try(read_byte(stream, DatabaseFileInvalidData))
  use _hash_table_section_start <- result.try(read_byte(
    stream,
    DatabaseFileInvalidData,
  ))

  use _records_count <- result.try(
    read_byte(stream, DatabaseFileInvalidData)
    |> result.map(fn(hash_table_size_byte) {
      hash_table_size_byte
      |> bit_array.base16_encode
      |> int.base_parse(16)
    })
    |> result.replace_error(DatabaseFileInvalidData),
  )
  use _records_with_expiry_count <- result.try(
    read_byte(stream, DatabaseFileInvalidData)
    |> result.map(fn(hash_table_size_byte) {
      hash_table_size_byte
      |> bit_array.base16_encode
      |> int.base_parse(16)
    })
    |> result.replace_error(DatabaseFileInvalidData),
  )

  recursive_data_read(stream, dict.new())
}

fn read_check_sum(
  stream: FileStream,
) -> Result(#(FileStream, BitArray), DatabaseFileError) {
  use check_sum <- result.try(
    stream
    |> file_stream.read_bytes_exact(8)
    |> result.replace_error(DatabaseFileChecksumError),
  )

  Ok(#(stream, check_sum))
}
