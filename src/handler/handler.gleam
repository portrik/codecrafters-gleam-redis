import gleam/bytes_builder
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor.{type Next}

import glisten.{type Connection, type Message}

import configuration/configuration.{type Message as ConfigurationMessage}
import messaging/parse
import messaging/response
import store/store.{type Message as StoreMessage}

pub fn response_handler(
  message: Message(a),
  state: Nil,
  connection: Connection(a),
  store store_subject: Subject(StoreMessage),
  configuration configuration_subject: Subject(ConfigurationMessage),
) -> Next(Message(a), Nil) {
  io.println("Received message!")

  let response =
    message
    |> parse.parse_bulk_message

  let response = case response {
    Error(_) -> "+UNKNOWN\r\n"
    Ok(command) ->
      response.handle_command(store_subject, configuration_subject, command)
  }

  let assert Ok(_) =
    connection
    |> glisten.send(bytes_builder.from_string(response))

  io.print("Responded with: ")
  io.debug(response)

  actor.continue(state)
}
