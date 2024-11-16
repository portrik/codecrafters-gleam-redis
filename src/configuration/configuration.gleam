import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor

import argv
import filepath

const timeout: Int = 5000

pub type Configuration {
  Configuration(directory: Option(String), database_filename: Option(String))
}

pub type ConfigurationKey {
  Dir
  DBFilename
}

pub type Message {
  Get(client: Subject(Option(String)), key: ConfigurationKey)

  Shutdown
}

pub fn new() -> Result(Subject(Message), actor.StartError) {
  actor.start(load_command_line(), handle_message)
}

pub fn close(actor_subject: Subject(Message)) -> Nil {
  actor.send(actor_subject, Shutdown)
}

pub fn get(
  configuration_subject: Subject(Message),
  key: ConfigurationKey,
) -> Option(String) {
  actor.call(configuration_subject, Get(_, key), timeout)
}

pub fn get_configuration_file_path(
  configuration_subject: Subject(Message),
) -> Option(String) {
  use directory <- option.then(actor.call(
    configuration_subject,
    Get(_, Dir),
    timeout,
  ))
  use filename <- option.then(actor.call(
    configuration_subject,
    Get(_, DBFilename),
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

    Get(client, key) -> {
      let value = case key {
        Dir -> configuration.directory
        DBFilename -> configuration.database_filename
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
    Configuration(directory: option.None, database_filename: option.None),
    fold_configration_argument,
  )
}

fn fold_configration_argument(
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
    _ -> current_configuration
  }
}
