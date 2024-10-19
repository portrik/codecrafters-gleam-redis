pub type Command {
  PING
  ECHO(content: String)
  SET(key: String, value: String)
  GET(key: String)
}
