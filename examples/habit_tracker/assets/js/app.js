import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfTokenElement = document.querySelector("meta[name='csrf-token']")
let csrfToken = csrfTokenElement?.getAttribute("content")

if (csrfToken) {
  let liveSocket = new LiveSocket("/live", Socket, {
    params: {_csrf_token: csrfToken}
  })

  liveSocket.connect()
}

