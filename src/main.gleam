import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, None}
import glisten.{type Connection, type Message}
import handler/handler
import replication/replication

import configuration/configuration
import store/file
import store/store

fn load_database_file(
  database_file: String,
) -> Option(Dict(String, store.Record)) {
  let database_data = file.load_database_file(database_file)

  case database_data {
    Ok(database_data) -> option.Some(database_data)
    Error(error) -> {
      io.println("Could not load database file due to an error")
      case error {
        file.DatabaseFileCannotBeFound ->
          io.println("File " <> database_file <> " could not be found")
        file.DatabaseFileInvalidMagicString ->
          io.println(
            "File " <> database_file <> " has invalid magic string header.",
          )
        file.DatabaseFileInvalidMetadata ->
          io.println("File " <> database_file <> " has invalid metadata.")
        file.DatabaseFileInvalidData ->
          io.println("File " <> database_file <> " has invalid data structure.")
        file.DatabaseFileChecksumError ->
          io.println("File " <> database_file <> " has incorrect checksum.")
      }

      option.None
    }
  }
}

pub fn main() {
  let assert Ok(configuration_subject) = configuration.new()
  let database_file =
    configuration.get_configuration_file_path(configuration_subject)
  let database_data = case database_file {
    option.Some(database_file) -> load_database_file(database_file)
    option.None -> option.None
  }

  let replication = configuration.get_replication(configuration_subject)
  let _replication = case replication {
    configuration.SlaveReplication(hostname, port) ->
      replication.connect_to_master(hostname, port)
    _ -> Ok(Nil)
  }

  let assert Ok(store_subject) = store.new(database_data)

  let assert Ok(_) =
    glisten.handler(
      fn(_connection) { #(Nil, None) },
      fn(message: Message(a), state: Nil, connection: Connection(a)) {
        handler.response_handler(
          message,
          state,
          connection,
          store_subject,
          configuration_subject,
        )
      },
    )
    |> glisten.serve(configuration.get_integer(
      configuration_subject,
      configuration.Port,
    ))

  process.sleep_forever()

  store.close(store_subject)
  configuration.close(configuration_subject)
}
