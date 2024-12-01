import gleam/bit_array
import gleam/result

import mug.{type Socket}

import messaging/format

pub type MasterConnectionError {
  UnableToConnect
  PingFailed
}

type MasterSocket(state) {
  MasterSocket(socket: Socket)
}

type MasterSocketPing {
  MasterSocketPing
}

type MasterSocketConfirmation {
  MasterSocketConfirmation
}

type MasterSocketSynchronize {
  MasterSocketSynchronize
}

fn send_ping(
  socket: MasterSocket(MasterSocketPing),
) -> Result(MasterSocket(MasterSocketConfirmation), MasterConnectionError) {
  let ping =
    ["PING"]
    |> format.format_to_resp_array
    |> bit_array.from_string

  let response =
    socket.socket
    |> mug.send(ping)

  case response {
    Ok(_) -> Ok(MasterSocket(socket.socket))
    Error(_) -> Error(UnableToConnect)
  }
}

fn send_confirmation(
  socket: MasterSocket(MasterSocketConfirmation),
) -> Result(MasterSocket(MasterSocketSynchronize), MasterConnectionError) {
  todo
}

fn send_synchronization(
  socket: MasterSocket(MasterSocketSynchronize),
) -> Result(Nil, MasterConnectionError) {
  todo
}

pub fn connect_to_master(
  hostname: String,
  port: Int,
) -> Result(Nil, MasterConnectionError) {
  let connection_options = mug.new(hostname, port)
  use socket <- result.try(
    connection_options
    |> mug.connect
    |> result.replace_error(UnableToConnect),
  )

  let ping_socket: MasterSocket(MasterSocketPing) = MasterSocket(socket)

  use _confirmation_socket <- result.try(send_ping(ping_socket))

  Ok(Nil)
}
