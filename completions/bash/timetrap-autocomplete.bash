#!/bin/bash
_timetrap ()
{
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmd="${COMP_WORDS[1]}"
  db_file=$(timetrap configure database_file)
  if [[ ( $cmd = s* || $cmd = d* ) && "$COMP_CWORD" = 2 ]]; then
    COMPREPLY=($(compgen -W "$(echo "select distinct sheet from entries where sheet not like '\_%';" | sqlite3 $db_file)" $cur))
    return
  elif [[ "$COMP_CWORD" = 1 ]]; then
    CMDS="archive backend configure display edit in kill list now out resume sheet week month"
    COMPREPLY=($(compgen -W "$CMDS" $cur))
  fi

}


complete -F _timetrap 't'
