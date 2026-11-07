fromjson? | [.["@timestamp"][11:19], .log.level, .message,
  (del(.["@timestamp"], .log, .process, .service, .ecs, .message, .tags, .error) | to_entries | map("\(.key)=\(.value)") | join(" ")),
  (if .error then "(\(.error.type): \(.error.message))" else "" end)] | map(select(. != "")) | join("  ")
