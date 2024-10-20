import gleam/erlang/process
import gleam/option.{None}
import glisten.{type Connection, type Message}
import handler/handler

import configuration/configuration
import store/store

pub fn main() {
  let assert Ok(store_subject) = store.new()
  let assert Ok(configuration_subject) = configuration.new()

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
    |> glisten.serve(6379)

  process.sleep_forever()

  store.close(store_subject)
  configuration.close(configuration_subject)
}
