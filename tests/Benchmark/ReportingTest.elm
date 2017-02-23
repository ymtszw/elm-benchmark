module Benchmark.ReportingTest exposing (..)

import Benchmark.LowLevel as LowLevel
import Benchmark.Reporting as Reporting
import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)
import Time


lazy : (() -> Fuzzer a) -> Fuzzer a
lazy fuzzer =
    Fuzz.andThen fuzzer Fuzz.unit


choice : List (Fuzzer a) -> Fuzzer a
choice choices =
    case choices |> List.map ((,) 1) |> Fuzz.frequency of
        Err err ->
            Debug.crash "error constructing fuzzer" err

        Ok fuzzer ->
            fuzzer


error : Fuzzer LowLevel.Error
error =
    choice
        [ Fuzz.constant LowLevel.StackOverflow
        , Fuzz.map LowLevel.UnknownError Fuzz.string
        ]


status : Fuzzer Reporting.Status
status =
    choice
        [ Fuzz.map Reporting.ToSize Fuzz.float
        , Fuzz.map3 Reporting.Pending Fuzz.float Fuzz.int (Fuzz.list Fuzz.float)
        , Fuzz.map Reporting.Failure error
        , Fuzz.map Reporting.Success (Fuzz.map2 Reporting.stats Fuzz.int (Fuzz.list Fuzz.float))
        ]


report : Fuzzer Reporting.Report
report =
    let
        fuzzer =
            Fuzz.frequency
                [ ( 2, Fuzz.map2 Reporting.Benchmark Fuzz.string status )
                , ( 1
                  , lazy
                        (\_ ->
                            Fuzz.map2 Reporting.Group
                                Fuzz.string
                                (Fuzz.map (flip (::) []) report)
                        )
                  )
                , ( 1, lazy (\_ -> Fuzz.map3 Reporting.Compare Fuzz.string report report) )
                ]
    in
        case fuzzer of
            Err err ->
                Debug.crash "error constructing fuzzer" err

            Ok fuzzer ->
                fuzzer



-- now, finally: the tests


sampleInterval : Test
sampleInterval =
    describe "sampleInterval"
        [ test "empty" <|
            \() ->
                Reporting.stats 1 []
                    |> Reporting.sampleInterval
                    |> Expect.equal Nothing
        , fuzz Fuzz.float "a single value" <|
            \a ->
                Reporting.stats 1 [ a ]
                    |> Reporting.sampleInterval
                    |> Expect.equal (Just ( a, a ))
        , fuzz2 Fuzz.float Fuzz.float "any two values" <|
            \a b ->
                Reporting.stats 1 [ a, b ]
                    |> Reporting.sampleInterval
                    |> Expect.equal (Just ( min a b, max a b ))
        ]


totalOperations : Test
totalOperations =
    describe "totalOperations"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal 1
        , fuzz (Fuzz.intRange 1 10000) "with many samples" <|
            \size ->
                size
                    |> List.range 1
                    |> List.map toFloat
                    |> Reporting.stats 1
                    |> Reporting.totalOperations
                    |> Expect.equal size
        , fuzz (Fuzz.intRange 1 (10 ^ 9)) "with many sample sizes" <|
            \size ->
                size
                    |> flip Reporting.stats [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal size
        ]


totalRuntime : Test
totalRuntime =
    describe "totalRuntime"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal 1
        , fuzz (Fuzz.list Fuzz.float) "with many samples" <|
            \samples ->
                samples
                    |> Reporting.stats 1
                    |> Reporting.totalRuntime
                    |> Expect.equal (List.sum samples)
        ]


meanRuntime : Test
meanRuntime =
    describe "meanRuntime"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.meanRuntime
                    |> Expect.equal 1
        , test "with one large and one small sample" <|
            \() ->
                Reporting.stats 1 [ 0, 2 ]
                    |> Reporting.meanRuntime
                    |> Expect.equal 1
        ]


operationsPerSecond : Test
operationsPerSecond =
    describe "operationsPerSecond"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal 1
        , test "when an operation takes longer than a second" <|
            \() ->
                Reporting.stats 1 [ 2 * Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal 0.5
        , fuzz (Fuzz.intRange 1 (1 ^ 6 * 5)) "fit into one second" <|
            \operations ->
                operations
                    |> flip Reporting.stats [ Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal (toFloat operations)
        , fuzz (Fuzz.intRange 1 40) "one operation per second for n seconds" <|
            \operations ->
                operations
                    |> List.range 1
                    |> List.map (always Time.second)
                    |> Reporting.stats 1
                    |> Reporting.operationsPerSecond
                    |> Expect.equal 1
        ]


serialization : Test
serialization =
    describe "serialization"
        [ fuzz report "round trip" <|
            \r ->
                r
                    |> Reporting.encoder
                    |> Encode.encode 0
                    |> Decode.decodeString Reporting.decoder
                    |> Expect.equal (Ok r)
        ]


all : Test
all =
    describe "reporting"
        [ sampleInterval
        , totalOperations
        , totalRuntime
        , meanRuntime
        , operationsPerSecond
        , serialization
        ]
