decodeb64() {
  echo -n "$1" | base64 --decode
}
encodeb64() {
  echo -n "$1" | base64
}
basicauth() {
  local user="$1"
  local password="$2"
  echo -n "$user:$password" | base64
}