#!/bin/bash



# Test execution method
source $(dirname `pwd`)/test/assert.sh

# List of tests to execute
declare -a TESTS=()

#
# Get the current and parent branch names
# based on https://gist.github.com/intel352/9761288#gistcomment-1774649
#
vbc_col=$(( $(git show-branch | grep '^[^\[]*\*' | head -1 | cut -d* -f1 | wc -c) - 1 ))
swimming_lane_start_row=$(( $(git show-branch | grep -n "^[\-]*$" | cut -d: -f1) + 1 ))
export CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
export PARENT_BRANCH=`git show-branch | tail -n +$swimming_lane_start_row | grep -v "^[^\[]*\[$CURRENT_BRANCH" | grep "^.\{$vbc_col\}[^ ]" | head -n1 | sed 's/.*\[\(.*\)\].*/\1/' | sed 's/[\^~].*//'`
if [ "" == "$PARENT_BRANCH" ]; then PARENT_BRANCH=master; fi

get_test_suite() {
    case $1 in
        Dockerfile|test/build.sh|release)
            echo "build;install;bower;md;grunt;gulp;node;npm;yarn"
            ;;
        test/run-tests.sh)
            echo "install;bower;md;grunt;gulp;node;npm;yarn"
            ;;
        bin/bower|test/bower.sh|test/resources/bower.json)
            echo "bower"
            ;;
        bin/generate-md|test/md.sh|test/resources/md/index.md)
            echo "md"
            ;;
        bin/grunt|test/grunt.sh|test/resources/Gruntfile.js)
            echo "grunt"
            ;;
        bin/gulp|test/gulp.sh|test/resources/gulpfile.js)
            echo "gulp"
            ;;
        bin/install.sh|test/install.sh)
            echo "install"
            ;;
        bin/node|test/node.sh|default)
            echo "node"
            ;;
        bin/npm|test/npm.sh)
            echo "npm"
            ;;
        bin/yarn|test/yarn.sh)
            echo "yarn"
            ;;
        test/resources/package.json)
            echo "npm;yarn"
            ;;
    esac
}

verbose=
if [ "-v" == "$1" ]; then
    verbose=-v
    shift
fi

#
# Add a test to the current list of tests to be executed
# Don't add duplicates. Keep list sorted by test name.
#
add_test() {
    echo "  Adding '$1' test suite..."
    tests=$(get_test_suite $1)

    set -f
    array=(${tests//;/ })
    for new_test in "${!array[@]}"; do
        echo "    - '${array[new_test]}'"
        is_current_test=0
        for current_test in "${!TESTS[@]}"; do
            if [ "${TESTS[current_test]}" == "${array[new_test]}" ]; then
                is_current_test=1
            fi
        done
        if [ 0 -eq $is_current_test ]; then
            TESTS+=("${array[new_test]}")
        fi
    done
    echo

    # Sort
    TESTS=(
        $(for a in "${TESTS[@]}"
        do
            echo "$a"
        done | sort)
    )
}

#
# Execute all the requested tests
# Don't add duplicates. Keep list sorted by test name.
#
exit_code=0
execute_tests() {
    echo "
  Executing tests..."
    for test in "${!TESTS[@]}"; do
        printf "    - ${TESTS[test]}... "
        if [ "build" == "${TESTS[test]}" ]; then
            bash "${TESTS[test]}.sh"
        else
            test_result=$(assert "${TESTS[test]}.sh" 0)
        fi
        result=$?
        if [ 0 -ne $result ]; then
            echo "failure (#$result)"
            exit_code=1
        else
            echo "success"
        fi
        if [ "-v" == "$1" ] || [ 0 -ne $result ]; then
            echo "$test_result"
            echo
        fi
    done
}

#
#
#
echo "
Analyzing changes: $PARENT_BRANCH <=> $CURRENT_BRANCH
"
run_tests=
if [ "" != "$1" ]; then
    add_test $1
else
    test_found=0
    for file in $(git diff --name-only $PARENT_BRANCH $CURRENT_BRANCH); do
        add_test $file
        test_found=1
    done
fi
if [ "$CURRENT_BRANCH" == "$PARENT_BRANCH" ] || [ "0" == "$test_found" ]; then
    add_test release
fi

execute_tests $verbose

echo "
  bower --version:       $($(dirname `pwd`)/bin/bower --version)
  generate-md --version: $($(dirname `pwd`)/bin/generate-md --version)
  grunt --version:       $($(dirname `pwd`)/bin/grunt --version)
  gulp --version:        $($(dirname `pwd`)/bin/gulp --version)
  node --version:        $($(dirname `pwd`)/bin/node --version)
  npm --version:         $($(dirname `pwd`)/bin/npm --version)
  yarn --version:        $($(dirname `pwd`)/bin/yarn --version)
"
exit $exit_code
