fromjson?
| select(.log.logger | startswith("ar.edu.um"))
| (if .log.level == "ERROR" then "\u001b[31m" elif .log.level == "WARN" then "\u001b[33m" else "" end) as $c
| $c + ([.service.name, .["@timestamp"][11:19], .log.level, .message,
    (del(.["@timestamp"], .log, .process, .service, .ecs, .message, .tags, .error) | to_entries | map("\(.key)=\(.value)") | join(" ")),
    (if .error then "(\(.error.type): \(.error.message))" else "" end)] | map(select(. != "")) | join("  ")) + "\u001b[0m"
