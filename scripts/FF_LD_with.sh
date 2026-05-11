#!/usr/bin/env bash
# Launch X-Plane with the FlightFactor 777-200ER's bundled libc++ / libc++abi
# preloaded. See docs/flightfactor-777-libcxx.md for the "why".

bundle="./Aircraft/FlightFactor777_200ER/modules/cpp-libs/stsff_aircraft_performance_lua/bundle"

LD_PRELOAD="${bundle}/libc++abi.so.1:${bundle}/libc++.so.1" exec "$@"
