{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving #-}

module Main where

import           Data.Aeson
import           Data.Bifunctor         (first)
import           Data.Foldable
import           Data.Text              (Text)
import qualified Data.Text              as T
import           Data.Text.Encoding     (decodeUtf8, encodeUtf8)
import qualified Data.Vector            as V
import qualified JSONPointer            as JP
import           Network.HTTP.Types.URI (urlDecode)

import           Test.Hspec
import           Test.QuickCheck        (Arbitrary(..), property)

import qualified Example

deriving instance Arbitrary JP.Pointer

instance Arbitrary JP.Token where
    arbitrary = JP.Token . T.pack <$> arbitrary

main :: IO ()
main = hspec $ do
    describe "example" $ do
        it "compiles and runs without errors" Example.main
    describe "pointers" $ do
        it "can be stored as JSON without changing its value" (property roundtrip)
        it "can be represented in a JSON string value" jsonString
        it "can be represented in a URI fragment identifier" uriFragment

roundtrip :: JP.Pointer -> Bool
roundtrip a = Just a == decode (encode a)

jsonString :: Expectation
jsonString = traverse_ resolvesTo
    [ (""      , specExample)
    , ("/foo"  , Array $ V.fromList ["bar", "baz"])
    , ("/foo/0", String "bar")
    , ("/"     , Number 0)
    , ("/a~1b" , Number 1)
    , ("/c%d"  , Number 2)
    , ("/e^f"  , Number 3)
    , ("/g|h"  , Number 4)
    , ("/i\\j" , Number 5)
    , ("/k\"l" , Number 6)
    , ("/ "    , Number 7)
    , ("/m~0n" , Number 8)
    ]

uriFragment :: Expectation
uriFragment = traverse_ resolvesTo . fmap (first decodeFragment) $
    [ ("#"      , specExample)
    , ("#/foo"  , Array $ V.fromList ["bar", "baz"])
    , ("#/foo/0", String "bar")
    , ("#/"     , Number 0)
    , ("#/a~1b" , Number 1)
    , ("#/c%25d", Number 2)
    , ("#/e%5Ef", Number 3)
    , ("#/g%7Ch", Number 4)
    , ("#/i%5Cj", Number 5)
    , ("#/k%22l", Number 6)
    , ("#/%20"  , Number 7)
    , ("#/m~0n" , Number 8)
    ]
  where
    decodeFragment :: Text -> Text
    decodeFragment = T.drop 1 . decodeUtf8 . urlDecode True . encodeUtf8

resolvesTo :: (Text, Value) -> Expectation
resolvesTo (t, expected) =
    case JP.unescape t of
        Left e  -> expectationFailure (show e <> " error for pointer: " <> show t)
        Right p -> JP.resolve p specExample `shouldBe` Right expected

specExample :: Value
specExample = object
    [ "foo"  .= (["bar", "baz"] :: [Text])
    , ""     .= (0 :: Int)
    , "a/b"  .= (1 :: Int)
    , "c%d"  .= (2 :: Int)
    , "e^f"  .= (3 :: Int)
    , "g|h"  .= (4 :: Int)
    , "i\\j" .= (5 :: Int)
    , "k\"l" .= (6 :: Int)
    , " "    .= (7 :: Int)
    , "m~n"  .= (8 :: Int)
    ]
