{-# LANGUAGE OverloadedStrings #-}

module Blossom.Parsing.LexerTest (
    tests
) where

import Test.HUnit (Test(..), (@=?))
import Blossom.Common.Name (testIdent)
import Blossom.Parsing.Lexer (tokenize)
import Blossom.Parsing.Token (Token(..))


tests :: Test
tests = TestLabel "Blossom.Parsing.Lexer" $ TestList [
    TestLabel "`tokenize`" $ TestList [
        TestLabel "integers" $ TestCase $
            let actual = tokenize' "0123456789 3 51333332"
                expected = Right [
                    TokInteger 123456789,
                    TokInteger 3,
                    TokInteger 51333332
                    ]
            in expected @=? actual,
        TestLabel "floats" $ TestCase $
            let actual = tokenize' "3.14159 1.414213 0.26340"
                expected = Right [
                    TokFloat 3.14159,
                    TokFloat 1.414213,
                    TokFloat 0.2634
                    ]
            in expected @=? actual,
        TestLabel "strings" $ TestCase $
            -- TODO: allow escaped quotations
            let actual = tokenize' "\"foobar\" \"\""
                expected = Right [
                    TokString "foobar",
                    TokString ""
                    ]
            in expected @=? actual,
        TestLabel "operators" $ TestCase $
            let actual = tokenize' ">= .^#* $~% <?--! --@ ~--"
                expected = Right [
                    operId ">=",
                    operId ".^#*",
                    operId "$~%",
                    operId "<?--!",
                    operId "--@",
                    operId "~--"
                    ]
            in expected @=? actual,
        TestLabel "small identifiers" $ TestCase $
            let actual = tokenize' "fo'0 bar' _FooBar"
                expected = Right [
                    smolId "fo'0",
                    smolId "bar'",
                    smolId "_FooBar"
                    ]
            in expected @=? actual,
        TestLabel "big identifiers" $ TestCase $
            let actual = tokenize' "F0o Bar' Foo'Bar"
                expected = Right [
                    bigId "F0o",
                    bigId "Bar'",
                    bigId "Foo'Bar"
                    ]
            in expected @=? actual,
        TestLabel "mixed" $ TestList [
            TestCase $
                let actual = tokenize'
                        "123 45.6 \"str\" ' ' !#$%&*+.<=>?@^|-~ aC'5a Kw'2"
                    expected = Right [
                        TokInteger 123,
                        TokFloat 45.6,
                        TokString "str",
                        TokChar ' ',
                        operId "!#$%&*+.<=>?@^|-~",
                        smolId "aC'5a",
                        bigId "Kw'2"
                        ]
                in expected @=? actual
            ]
        ]
    ]
    where
        tokenize' src = tokenize src "" ""

smolId :: String -> Token
smolId = TokSmallId . testIdent

bigId :: String -> Token
bigId = TokBigId . testIdent

operId :: String -> Token
operId = TokOperator . testIdent
