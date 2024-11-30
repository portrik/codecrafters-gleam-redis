import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import gleam/string
import ids/ulid

import argv
import filepath

const timeout: Int = 5000

const default_port: Int = 6379

pub opaque type Configuration {
  Configuration(
    directory: Option(String),
    database_filename: Option(String),
    port: Int,
    replication: Replication,
  )
}

pub type Replication {
  MasterReplication(id: String, offset: Int)
  SlaveReplication(master_host: String, master_port: Int)
}

pub type ConfigurationKeyString {
  Dir
  DBFilename
}

pub type ConfigurationKeyInteger {
  Port
}

pub type Message {
  GetStringValue(client: Subject(Option(String)), key: ConfigurationKeyString)
  GetIntegerValue(client: Subject(Int), key: ConfigurationKeyInteger)
  GetReplication(client: Subject(Replication))

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

pub fn get_replication(configuration_subject: Subject(Message)) -> Replication {
  actor.call(configuration_subject, GetReplication, timeout)
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

    GetReplication(client) -> {
      process.send(client, configuration.replication)

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
      replication: MasterReplication(ulid.generate(), 0),
    ),
    fold_configuration_argument,
  )
}

fn parse_replication(current: Replication, arguments: String) -> Replication {
  let arguments = string.split(arguments, " ")

  let values = case arguments {
    [hostname, port] -> {
      let port = int.parse(port)

      case port {
        Ok(port) -> option.Some(#(hostname, port))
        Error(_) -> option.None
      }
    }
    _ -> option.None
  }

  case values {
    option.Some(#(hostname, port)) -> SlaveReplication(hostname, port)
    option.None -> current
  }
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
    ["--replicaof", arguments] ->
      Configuration(
        ..current_configuration,
        replication: parse_replication(
          current_configuration.replication,
          arguments,
        ),
      )
    _ -> current_configuration
  }
}
