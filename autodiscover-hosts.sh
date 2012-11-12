#! /bin/bash
#
#                _                                        _       
#     /\        | |                                      | |      
#    /  \  _   _| |_ ___   __ _  ___ _ __   ___ _ __ __ _| |_ ___ 
#   / /\ \| | | | __/ _ \ / _` |/ _ \ '_ \ / _ \ '__/ _` | __/ _ \
#  / ____ \ |_| | |_ (_) | (_| |  __/ | | |  __/ | | (_| | |_  __/
# /_/    \_\__,_|\__\___/ \__, |\___|_| |_|\___|_|  \__,_|\__\___|
#                          __/ |                                  
#                         |___/                  
#		       _ _   _   _          
#		       | | | | | | |         
#		   __ _| | | | |_| |__   ___ 
#		  / _` | | | | __| '_ \ / _ \
#		 | (_| | | | | |_| | | |  __/
#		  \__,_|_|_|  \__|_| |_|\___|
#	   _____ _____           _____  _    _  _____ _ 
#	  / ____|  __ \    /\   |  __ \| |  | |/ ____| |
#	 | |  __| |__) |  /  \  | |__) | |__| | (___ | |
#	 | | |_ |  _  /  / /\ \ |  ___/|  __  |\___ \| |
#	 | |__| | | \ \ / ____ \| |    | |  | |____) |_|
#	  \_____|_|  \_\_/    \_\_|    |_|  |_|_____/(_)
#							
                             
# Configuration:
# This is your Graphite base URL
GRAPHITE_HOST=http://<<your domain here>>
# Where do we store the machines that we find in graphite?
GDASH_DIR=/var/www/gdash/graph_templates/machines
# Where are your graph templates stored?
GDASH_TPL_DIR=templates

# change the query param to filter down to hosts starting with 
# that data source name. F.ex., if your hosts are host001, host002, etc
# then keep the config below
GURL_MACHINE_LIST="$GRAPHITE_HOST/metrics/find/?query=host*&format=completer&contexts=1&path=&node=GraphiteTree"

# Drop a file named "host_match" in your templates directory. Content is one line,
# starts with the name of templates you want to match (name of the directory that
# holds the templates), colon seperator, then a regex that gets mapped against the host
# name. F.ex. you could match host-db-master like "^host-db-*", which should than 
# make those graphs available for any hosts that are databases. Example:
# os.basic:^host-db-*

###### ---- ###### [ END OF CONFIGURATION ] ###### ---- ######

GURL_DS_LIST="$GRAPHITE_HOST/metrics/find/find/?query=%sformat=completer&contexts=1&path=&node=GraphiteTree"
MACHINES=`curl  --silent $GURL_MACHINE_LIST | tr '"' '\n' | sed 's/\.//g' | uniq `

MAPPING=(  )
HOST_MATCH_LIST=`ls -1 $GDASH_DIR/../$GDASH_TPL_DIR/*/host_match`
for HOST_MATCH in $HOST_MATCH_LIST
do
	TMP=`cat $HOST_MATCH`
	MAPPING=("${MAPPING[@]}" "$TMP")
done

# Loop over all machines we have found in Graphite, see if it matches
# any of the regexes, if they do, add that as a template to it's 
# dash.yaml file
for MACHINE in $MACHINES
do
  TPL=""
  SHORT_MACHINE=$MACHINE
  if [[ $MACHINE =~ (mp-[a-z0-9]*).* ]]; then
    SHORT_MACHINE="${BASH_REMATCH[1]}"
  fi
  echo "Found machine: $SHORT_MACHINE"
  for line in "${MAPPING[@]}"; do
    TEMPLATE="${line%%:*}"
    REGEX="${line#*:}"
    if [[ $MACHINE =~ $REGEX ]]
    then
      echo "  * adding $TEMPLATE"
      TPL=$TPL$'\n'" - $GDASH_TPL_DIR/$TEMPLATE"
    fi
  done
  mkdir -p $GDASH_DIR/$MACHINE
  cat > $GDASH_DIR/$MACHINE/dash.yaml <<End-of-Content
:name: $SHORT_MACHINE
:description: $MACHINE

:include_graphs:
$TPL

:graph_properties:
  :servers: [ $MACHINE ]
End-of-Content
done
