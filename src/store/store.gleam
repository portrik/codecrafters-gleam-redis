import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/order
import gleam/otp/actor

import birl.{type Time}
import birl/duration

const timeout: Int = 5000

type ValueError {
  ValueExpired
  ValueMissing
}

pub type Message {
  Get(client: Subject(Option(String)), key: String)
  Set(key: String, value: String, expiration: Option(Int))

  Shutdown
}

pub type Record {
  Record(value: String, created_at: Time, expires_at: Option(Time))
}

pub fn new() -> Result(Subject(Message), actor.StartError) {
  actor.start(dict.new(), handle_message)
}

pub fn close(store_subject: Subject(Message)) -> Nil {
  actor.send(store_subject, Shutdown)
}

pub fn get(store_subject: Subject(Message), key: String) -> Option(String) {
  actor.call(store_subject, Get(_, key), timeout)
}

pub fn set(
  store_subject: Subject(Message),
  key: String,
  value: String,
  expiration: Option(Int),
) -> Nil {
  actor.send(store_subject, Set(key, value, expiration))
}

fn handle_message(
  message: Message,
  store: Dict(String, Record),
) -> actor.Next(Message, Dict(String, Record)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Get(client, key) -> {
      let #(store, value) = get_item(store, key)
      process.send(client, value)

      actor.continue(store)
    }

    Set(key, value, expiration) -> {
      let store =
        store
        |> set_item(key, value, expiration)

      actor.continue(store)
    }
  }
}

fn get_item(
  store: Dict(String, Record),
  key: String,
) -> #(Dict(String, Record), Option(String)) {
  let value =
    store
    |> dict.get(key)
    |> option.from_result
    |> option.map(fn(value) {
      case value.expires_at {
        option.None -> Ok(value.value)
        option.Some(expires_at) -> {
          case birl.compare(birl.now(), expires_at) {
            order.Lt -> Ok(value.value)
            _ -> Error(ValueExpired)
          }
        }
      }
    })
    |> option.unwrap(Error(ValueMissing))

  case value {
    Ok(value) -> #(store, option.Some(value))
    Error(ValueMissing) -> #(store, option.None)
    Error(ValueExpired) -> #(dict.delete(store, key), option.None)
  }
}

fn set_item(
  store: Dict(String, Record),
  key: String,
  value: String,
  expiration: Option(Int),
) -> Dict(String, Record) {
  let created_at = birl.now()

  let expires_at = case expiration {
    option.None -> option.None
    option.Some(value) ->
      value
      |> duration.milli_seconds
      |> birl.add(created_at, _)
      |> option.Some
  }

  store
  |> dict.insert(key, Record(value, created_at, expires_at))
}
