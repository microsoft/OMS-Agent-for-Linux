#!/usr/bin/env python

from __future__ import print_function
import sys
from optparse import OptionParser


def print_err(message):
    print(message, file=sys.stderr)


def usage():
    print_err(sys.argv[0] + " -w <workspace id> -s <shared key>")
    print_err("  -s:   Shared key")
    print_err("  -v:   Verbose output")
    print_err("  -w:   Workspace ID")
    sys.exit(1)


def parse_options(args):
    parser = OptionParser()
    # parser.add_option("-h", "--help", action="store_true")
    parser.add_option("-v", "--verbose", action="store_true")
    parser.add_option("-s", "--shared_key", type="string")
    parser.add_option("-w", "--workspace_id", type="string")
    (options, leftover) = parser.parse_args(args)
    if len(leftover):
        print_err("Unparsed options error : " + " ".join(leftover))
        usage()
    return options


def main():
    options = parse_options(sys.argv[1:])

    if options.shared_key is None or options.workspace_id is None:
        print_err("Qualifiers -w and -s are mandatory")
        usage()

    print(options.verbose)
    print(options.shared_key, options.workspace_id)


if __name__ == "__main__":
    main()