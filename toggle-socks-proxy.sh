#!/usr/bin/env bash

# AUTHOR:   Steve Ward [steve at tech-otaku dot com]
# URL:      https://github.com/tech-otaku/toggle-socks-proxy.git
# README:   https://github.com/tech-otaku/toggle-socks-proxy/blob/main/README.md



# # # # # # # # # # # # # # # # 
# DEFAULTS
#

unset LOCALPORT MODE NETWORK REMOTEPORT REMOTEHOST REMOTEUSER 

LOCALPORT=11080
MODE=start
REMOTEPORT=22



# # # # # # # # # # # # # # # # 
# FUNCTION DECLARATIONS
#

# Function to display usage help
    function usage {
        cat << EOF
                    
    Syntax: ./$(basename $0) [options]

    options:
    -h                      This help message
    -l LOCALPORT            Defaults to '11080' if omitted
    -m MODE                 Defaults to 'start' if omitted                 
    -n NETWORK              Required
    -p REMOTEPORT           Defaults to '22' if omitted
    -r REMOTEHOST           Required if '-m start'
    -u REMOTEUSER           Required if '-m start'

    Examples: ./$(basename $0) -m start -n Wi-Fi -l 11080 -u steve -r 203.0.113.5 -p 5822 
              ./$(basename $0) -m stop -n Wi-Fi
    
EOF
    }



# # # # # # # # # # # # # # # # 
# COMMAND-LINE OPTIONS
#

# Exit with error if no command line options given
    if [[ ! $@ =~ ^\-.+ ]]; then
        printf "\nERROR: * * * No options given. * * *\n"
        usage
        exit 1
    fi

# Prevent an option that expects an argument, taking the next option as an argument if its argument is omitted (i.e. -s -t /full/path/to/target/directory)
    while getopts ':hl:m:n:p:r:u:' opt; do
        if [[ $OPTARG =~ ^\-.? ]]; then
            printf "\nERROR: * * * '%s' is not valid argument for option '-%s'\n" $OPTARG $opt
            usage
            exit 1
        fi
    done

# Reset OPTIND so getopts can be called a second time
    OPTIND=1        

# Process command line options
    while getopts ':hl:m:n:p:r:u:' opt; do
        case $opt in
            h)
                usage
                exit 0
                ;;
            l) 
                LOCALPORT=$OPTARG 
                ;;
            m) 
                MODE=$OPTARG 
                ;;
            n) 
                NETWORK=$OPTARG 
                ;;
            p) 
                REMOTEPORT=$OPTARG 
                ;;
            r) 
                REMOTEHOST=$OPTARG 
                ;;
            u) 
                REMOTEUSER=$OPTARG 
                ;;
            :) 
                printf "\nERROR: * * * Argument missing from '-%s' option * * *\n" $OPTARG
                usage
                exit 1
                ;;
            ?) 
                printf "\nERROR: * * * invalid option: '-%s'\n * * * " $OPTARG
                usage
                exit 1
                ;;
        esac
    done

# Network service is required for both 'start' and 'stop'
if [ -z $NETWORK ]; then
    echo "ERROR: No network service specified."
    exit 1
fi

if [[ ! $MODE =~ start|stop ]]; then
    printf "ERROR: Invalid mode '$MODE'. Use 'start' or 'stop' only."
    exit 1
elif [ $MODE == "start" ]; then
    # Remote host is only required for 'start'
    if [ -z $REMOTEHOST ]; then
        echo "ERROR: No remote host specified."
        exit 1
    fi
    # Remote user is only required for 'start'
    if [ -z $REMOTEUSER ]; then
        echo "ERROR: No remote user specified."
        exit 1
    fi
    
fi

# Check if the given network service exists
EXISTS=0    # false
while read SERVICE; do
    if [[ $NETWORK == $SERVICE ]]; then
        EXISTS=1    # true
        break
    fi
done < <(networksetup -listallnetworkservices | tail -n +2)

if ! (($EXISTS)); then
    printf "ERROR: Network Service '$NETWORK' doesn't exist."
    exit 1
fi 

curl --socks5-hostname 127.0.0.1:"${LOCALPORT}" google.com > /dev/null 2>&1    # Exits with 0 if SOCKS proxy is active on 'LOCALPORT' or 7 if not. Test with `echo $?`
SOCKSACTIVE=$(echo $?)

if [ $MODE == start ]; then

    if [ "${SOCKSACTIVE}" -ne 0 ]; then
        ssh -p "${REMOTEPORT}" -D "${LOCALPORT}" -f -N "${REMOTEUSER}"@"${REMOTEHOST}"
        printf "INFO: SOCKS proxy (${REMOTEHOST}:${REMOTEPORT}) established on local port ${LOCALPORT}.\n"
    fi
    
    networksetup -setsocksfirewallproxy "${NETWORK}" "127.0.0.1" "${LOCALPORT}" "off"    # Automatically turns-on SOCKS proxy. No need to explicitly turn-on with `networksetup -setsocksfirewallproxystate "${NETWORK}" "on"`
    printf "INFO: Network service '${NETWORK}' configured to use SOCKS proxy on port ${LOCALPORT}.\n"
    #networksetup -setsocksfirewallproxystate "${NETWORK}" "on"
    
else

    if [ $(networksetup -getsocksfirewallproxy Wi-Fi | grep ^Enabled | cut -d ' ' -f2) == "Yes" ]; then
        networksetup -setsocksfirewallproxystate "${NETWORK}" "off"
        printf "INFO: Network service '${NETWORK}' configured NOT to use a SOCKS proxy.\n"
    fi

    if [ "${SOCKSACTIVE}" -eq 0 ]; then
        kill $(ps -ef | grep '\-D 11080' | grep -v grep | awk -F" " '{print $2}')
        printf "INFO: SOCKS proxy disconnected on local port ${LOCALPORT}.\n"
    fi

fi