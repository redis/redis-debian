#!/bin/bash

slack_format_success_message() {

jq --arg release_tag "$1" --arg url_prefix "$1" --arg footer "$3" --arg env "$4" '
{
  icon_emoji: ":redis-circle:",
  text: (":debian: Debian Packages Published for Redis: " + $release_tag + " (" + $env + ")")),
  blocks: [
    {
      "type": "header",
      "text": { "type": "plain_text", "text": (":debian: Debian Packages Published for Release " + $release_tag) }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": (
          "The following packages have been published:\n\n" +
          (
            to_entries
            | map(
                "Distribution: *" + .key + "*\n" +
                (
                  .value | to_entries
                  | map(
                      "  Architecture: *" + .key + "*\n" +
                      (
                        .value
                        | map("    • <" + $url_prefix + "/" + $dist + "/r/re/" + . + "|" + . + ">")
                        | join("\n")
                      )
                    )
                  | join("\n")
                )
              )
            | join("\n\n")
          )
        )
      }
    },
    {
      "type": "context",
      "elements": [
        { "type": "mrkdwn", "text": $footer }
      ]
    }
  ]
}'
}