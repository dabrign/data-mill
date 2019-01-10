# variables to mandatorily return in output
VARS=(LOCATION ACTION)

OPTIONS=":dsrliut:f:c:"

while getopts $OPTIONS opt; do
  case $opt in
    d)
      echo "-d: debug mode enabled, spawning environment"
      ACTION="debug"
      break
      ;;
    s)
      echo "-s: start existing cluster without installing further dependencies"
      ACTION="start"
      ;;
    r)
      echo "-r: running to remote cluster"
      LOCATION="remote"
      ;;
    l)
      echo "-l: running local cluster"
      LOCATION="local"
      ;;
    i)
      echo "-i: installing infrastructure"
      ACTION="install"
      ;;
    u)
      echo "-u: uninstalling infrastructure"
      ACTION="delete"
      ;;
    t)
      echo "-t: overwriting target cluster configuration filename with $OPTARG" >&2
      TARGET_FILE=$OPTARG
      ;;
    f)
      echo "-f: overwriting default component configuration filename with $OPTARG" >&2
      CONFIG_FILE=$OPTARG
      ;;
    c)
      echo "-c: running for the sole component $OPTARG" >&2
      COMPONENT=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# print usage if any of the variables is not set
if [ "$ACTION" != "debug" ]; then
  for var in "${VARS[@]}"
  do
    if [ -z ${!var} ]; then
      echo "Usage: $0 [debug-mode] [params] [options]"
      echo "  debug mode:"
      echo "    DEBUG: -d"
      echo "  params:"
      echo "    LOCATION: -l (local cluster), -r (remote cluster)"
      echo "    ACTION: -s (start only), -i (install), -u (uninstall)"
      echo "  options:"
      echo "    CONFIG_FILE: -f filename.yaml"
      echo "      -> overwrites the default component configuration filename"
      echo "    TARGET_FILE: -t filename.yaml"
      echo "      -> overwrites the default k8s configuration filename"
      echo "    COMPONENT: -c component_name"
      exit 1
    fi
  done
fi
