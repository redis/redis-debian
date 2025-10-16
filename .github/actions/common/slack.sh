#!/bin/bash

slack_format_success_message() {
jq --arg release_tag "$1" --arg url_prefix "$2" --arg footer "$3" --arg env "$4" '
def generate_repo_prefix(package_name):
  package_name[:1] + "/" + package_name[:2];
{
  "icon_emoji": ":redis-circle:",
  "text": (":debian: Debian Packages Published for Redis: " + $release_tag + " (" + $env + ")"),
  "blocks": (
    [
      {
        "type": "header",
        "text": { "type": "plain_text", "text": (":debian: Debian Packages Published for Release " + $release_tag) }
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "The following packages have been published:"
        }
      }
    ] +
    (
      to_entries
      | map(
          . as $dist_entry |
          .value | to_entries
          | map({
              "type": "section",
              "text": {
                "type": "mrkdwn",
                "text": (
                  "Distribution: *" + $dist_entry.key + "* | Architecture: *" + .key + "*\n" +
                  (
                    .value
                    | map("• <" + $url_prefix + "/" + $dist_entry.key + "/" + generate_repo_prefix(.) + "/" + . + "|" + . + ">")
                    | join("\n")
                  )
                )
              }
            })
        )
      | flatten
    ) +
    [
      {
        "type": "context",
        "elements": [
          { "type": "mrkdwn", "text": $footer }
        ]
      }
    ]
  )
}'
}