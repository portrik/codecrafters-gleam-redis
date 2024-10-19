import gleam/bytes_builder
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/option
import gleam/otp/actor.{type Next}

import glisten.{type Connection, type Message}

import messaging/parse
import messaging/response
import store/actor as actor_store

pub fn response_handler(
  message: Message(a),
  state: Nil,
  connection: Connection(a),
  store_actor: Subject(actor_store.Message),
) -> Next(Message(a), Nil) {
  io.println("Received message!")

  let response =
    message
    |> parse.parse_bulk_message

  let response = case response {
    option.None -> "UNKNOWN_COMMAND"
    option.Some(command) -> response.handle_command(store_actor, command)
  }

  let assert Ok(_) =
    connection
    |> glisten.send(bytes_builder.from_string(response))

  io.println("Responded with " <> response)

  actor.continue(state)
}
