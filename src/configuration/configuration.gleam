import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result

import argv
import filepath

const timeout: Int = 5000

const default_port: Int = 6379

pub type Configuration {
  Configuration(
    directory: Option(String),
    database_filename: Option(String),
    port: Int,
    replication: List(#(String, String)),
  )
}

pub type ConfigurationKeyString {
  Dir
  DBFilename
}

pub type ConfigurationKeyStringTupleList {
  Replication
}

pub type ConfigurationKeyInteger {
  Port
}

pub type Message {
  GetStringValue(client: Subject(Option(String)), key: ConfigurationKeyString)
  GetIntegerValue(client: Subject(Int), key: ConfigurationKeyInteger)
  GetStringTupleListValue(
    client: Subject(List(#(String, String))),
    key: ConfigurationKeyStringTupleList,
  )

  Shutdown
}

pub fn new() -> Result(Subject(Message), actor.StartError) {
  actor.start(load_command_line(), handle_message)
}

pub fn close(actor_subject: Subject(Message)) -> Nil {
  actor.send(actor_subject, Shutdown)
}

pub fn get_string(
  configuration_subject: Subject(Message),
  key: ConfigurationKeyString,
) -> Option(String) {
  actor.call(configuration_subject, GetStringValue(_, key), timeout)
}

pub fn get_integer(
  configuration_subject: Subject(Message),
  key: ConfigurationKeyInteger,
) -> Int {
  actor.call(configuration_subject, GetIntegerValue(_, key), timeout)
}

pub fn get_string_tuple_list(
  configuration_subject: Subject(Message),
  key: ConfigurationKeyStringTupleList,
) -> List(#(String, String)) {
  actor.call(configuration_subject, GetStringTupleListValue(_, key), timeout)
}

pub fn get_configuration_file_path(
  configuration_subject: Subject(Message),
) -> Option(String) {
  use directory <- option.then(actor.call(
    configuration_subject,
    GetStringValue(_, Dir),
    timeout,
  ))
  use filename <- option.then(actor.call(
    configuration_subject,
    GetStringValue(_, DBFilename),
    timeout,
  ))

  option.Some(filepath.join(directory, filename))
}

fn handle_message(
  message: Message,
  configuration: Configuration,
) -> actor.Next(Message, Configuration) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    GetStringValue(client, key) -> {
      let value = case key {
        Dir -> configuration.directory
        DBFilename -> configuration.database_filename
      }

      process.send(client, value)

      actor.continue(configuration)
    }

    GetIntegerValue(client, key) -> {
      let value = case key {
        Port -> configuration.port
      }

      process.send(client, value)

      actor.continue(configuration)
    }

    GetStringTupleListValue(client, key) -> {
      let value = case key {
        Replication -> configuration.replication
      }

      process.send(client, value)

      actor.continue(configuration)
    }
  }
}

fn load_command_line() -> Configuration {
  argv.load().arguments
  |> list.sized_chunk(2)
  |> list.fold(
    Configuration(
      directory: option.None,
      database_filename: option.None,
      port: default_port,
      replication: [
        #("role", "master"),
        #("connected_slaves", "0"),
        #("master_replid", "f1c419b3-9be7-451e-9368-e9d81fdbc591"),
        #("master_repl_offset", "0"),
      ],
    ),
    fold_configuration_argument,
  )
}

fn fold_configuration_argument(
  current_configuration: Configuration,
  argument: List(String),
) -> Configuration {
  case argument {
    ["--dir", value] ->
      Configuration(..current_configuration, directory: option.Some(value))
    ["--dbfilename", value] ->
      Configuration(
        ..current_configuration,
        database_filename: option.Some(value),
      )
    ["--port", value] ->
      Configuration(
        ..current_configuration,
        port: value
          |> int.parse
          |> result.unwrap(default_port),
      )
    _ -> current_configuration
  }
}
