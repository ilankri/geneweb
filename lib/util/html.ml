let parse ?context s =
  s |> Markup.string |> Markup.parse_html ?context |> Markup.signals

let pretty_print ?escape_attribute ?escape_text elements =
  elements
  |> Markup.write_html ?escape_text ?escape_attribute
  |> Markup.to_string

let map ?context ?escape_attribute ?escape_text f s =
  s |> parse ?context |> Markup.map f
  |> pretty_print ?escape_attribute ?escape_text

let text_content s = s |> parse |> Markup.text |> Markup.to_string
let is_plain_text s = String.equal (text_content s) s
