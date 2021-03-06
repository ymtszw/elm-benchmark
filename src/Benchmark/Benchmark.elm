module Benchmark.Benchmark exposing (..)

{-| hey, don't publish me please!
-}

import Benchmark.LowLevel as LowLevel exposing (Operation)
import Benchmark.Status exposing (Status)


type Benchmark
    = Single String Operation Status
    | Series String (List ( String, Operation, Status ))
    | Group String (List Benchmark)
