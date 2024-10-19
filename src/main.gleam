import gleam/erlang/process
import gleam/option.{None}
import glisten.{type Connection, type Message}
import handler/handler

import store/store

pub fn main() {
  let assert Ok(store_actor) = store.new()

  let assert Ok(_) =
    glisten.handler(
      fn(_connection) { #(Nil, None) },
      fn(message: Message(a), state: Nil, connection: Connection(a)) {
        handler.response_handler(message, state, connection, store_actor)
      },
    )
    |> glisten.serve(6379)

  process.sleep_forever()
  store.close(store_actor)
}
