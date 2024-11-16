import birl/duration
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/otp/actor.{type Next}

import birl.{type Time}

const timeout: Int = 5000

pub type Message {
  Get(client: Subject(Option(String)), key: String)
  Set(key: String, value: String, expiration: Option(Time))
  Keys(client: Subject(List(String)), pattern: String)

  Shutdown
}

pub type Record {
  Record(value: String, expires_at: Option(Time))
}

pub fn new(
  initial_data: Option(Dict(String, Record)),
) -> Result(Subject(Message), actor.StartError) {
  actor.start(option.unwrap(initial_data, dict.new()), handle_message)
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
  expiration: Option(Time),
) -> Nil {
  actor.send(store_subject, Set(key, value, expiration))
}

pub fn keys(store_subject: Subject(Message), pattern: String) -> List(String) {
  actor.call(store_subject, Keys(_, pattern), timeout)
}

fn get_value_from_store(
  store: Dict(String, Record),
  key: String,
) -> Option(String) {
  use stored_value <- option.then(
    store
    |> dict.get(key)
    |> option.from_result,
  )

  let expiration_time = case stored_value.expires_at {
    option.None -> birl.add(birl.now(), duration.years(1))
    option.Some(expiration) -> expiration
  }

  case birl.compare(birl.now(), expiration_time) == order.Lt {
    True -> option.Some(stored_value.value)
    False -> option.None
  }
}

fn handle_get(
  store: Dict(String, Record),
  client: Subject(Option(String)),
  key: String,
) -> Next(Message, Dict(String, Record)) {
  let value = get_value_from_store(store, key)
  process.send(client, value)

  actor.continue(store)
}

fn handle_set(
  store: Dict(String, Record),
  key: String,
  value: String,
  expiration: Option(Time),
) -> Next(Message, Dict(String, Record)) {
  actor.continue(
    store
    |> dict.insert(key, Record(value, expiration)),
  )
}

fn handle_keys(
  store: Dict(String, Record),
  client: Subject(List(String)),
  pattern: String,
) -> Next(Message, Dict(String, Record)) {
  let keys = case pattern {
    "*" -> dict.keys(store)
    pattern -> {
      io.println("Pattern \"" <> pattern <> "\" is not supported")

      list.new()
    }
  }

  client
  |> process.send(keys)

  actor.continue(store)
}

fn handle_message(
  message: Message,
  store: Dict(String, Record),
) -> actor.Next(Message, Dict(String, Record)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)

    Get(client, key) -> handle_get(store, client, key)

    Set(key, value, expiration) -> handle_set(store, key, value, expiration)

    Keys(client, pattern) -> handle_keys(store, client, pattern)
  }
}
