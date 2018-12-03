#!/bin/bash

CGROUPS_MEM_LIMIT_BYTES=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)

if [[ "$CGROUPS_MEM_LIMIT_BYTES" == "9223372036854771712" || "X${CGROUPS_MEM_LIMIT_BYTES}X" == "XX" ]]; then
    echo "There is no cgroups memory limit in place, falling back to default JVM Xmx behavior (not setting any Xmx)."
    JAVA_XMX=""
else
    NON_HEAP_MEMORY_MB=$(($JAVA_NON_HEAP_MEMORY_BYTES/1024/1024))
    CGROUPS_MEM_LIMIT_MB=$(($CGROUPS_MEM_LIMIT_BYTES/1024/1024))
    XMX_LIMIT_MB=$(($CGROUPS_MEM_LIMIT_MB-$NON_HEAP_MEMORY_MB))
    echo "Container has a $CGROUPS_MEM_LIMIT_MB mb memory limit, $NON_HEAP_MEMORY_MB mb is reserved for non heap, using Xmx=${XMX_LIMIT_MB}m."
    JAVA_XMX=-Xmx${XMX_LIMIT_MB}m
fi

OPTS="$JAVA_XMX \
-XX:MaxMetaspaceSize=$JAVA_MAX_METASPACE_SIZE \
-Xss$JAVA_STACK_SIZE \
-XX:ReservedCodeCacheSize=$JAVA_RESERVED_CODE_CACHE_SIZE \
-XX:CompressedClassSpaceSize=$JAVA_COMPRESSED_CLASS_SPACE_SIZE \
-XX:MaxDirectMemorySize=$JAVA_MAX_DIRECT_MEMORY_SIZE \
-XX:+ExitOnOutOfMemoryError \
$JMX_CONFIG \
$JAVA_OPTS"

echo "Java launch options: $OPTS"

red="$(tput setaf 1)"
yellow="$(tput setaf 3)"
reset="$(tput sgr0)"
bold="$(tput bold)"

function warn() {
    echo
    echo "${yellow}********************************************************************************${reset}"
    echo
    echo -en "  $1"
    echo
    echo
    echo "${yellow}********************************************************************************${reset}"    
}

function error() {
	echo
    echo "${red}${bold}ERROR: ${reset}$1"    
}

JAVAC_VERSION=$(javac -version)
if [[ $? -ne 0 ]]; then
	export TEXT=$(cat << WARNING 
${bold}${red}                            DEPRECATION WARNING                            ${reset}
${bold}The pure JRE image docker-openjdk-springboot:8-jre is no longer supported!${reset}
  You will no longer receive any updates or security fixes for this version.
  You should migrate to the docker-openjdk-springboot:8-jdk image (or a later 
    version) as soon as possible.
WARNING
)
	warn "$TEXT"
    echo
    echo "Continuing in 10 seconds ..."
    echo
    sleep 10
fi

if [ -f "$SERVICE_JAR" ]; then
	exec java $OPTS -jar $SERVICE_JAR
elif [ -d "$SERVICE_FOLDER" ]; then
	exec java $OPTS -cp $SERVICE_FOLDER org.springframework.boot.loader.JarLauncher
else
	error "Cannot start: Must supply either $SERVICE_JAR or $SERVICE_FOLDER"
fi
