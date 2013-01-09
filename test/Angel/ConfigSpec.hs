{-# LANGUAGE OverloadedStrings #-}
module Angel.ConfigSpec (spec) where

import Angel.Data hiding (spec)
import Angel.Config

import Control.Exception.Base
import Data.Configurator.Types (Value(..))

import Test.Hspec
import qualified Test.Hspec as H (Spec)

spec :: H.Spec
spec = do
  describe "modifyProg" $ do
    it "modifies exec" $
      modifyProg prog "exec" (String "foo") `shouldBe`
      prog { exec = Just "foo"}

    it "errors for non-string execs" $
      evaluate (modifyProg prog "exec" (Bool True)) `shouldThrow`
      anyErrorCall

    it "modifies delay for positive numbers" $
      modifyProg prog "delay" (Number 1) `shouldBe`
      prog { delay = Just 1}
    it "modifies delay for 0" $
      modifyProg prog "delay" (Number 0) `shouldBe`
      prog { delay = Just 0}
    it "errors on negative delays" $
      evaluate (modifyProg prog "delay" (Number (-1))) `shouldThrow`
      anyErrorCall

    it "modifies stdout" $
      modifyProg prog "stdout" (String "foo") `shouldBe`
      prog { stdout = Just "foo"}
    it "errors for non-string stdout" $
      evaluate (modifyProg prog "stdout" (Bool True)) `shouldThrow`
      anyErrorCall

    it "modifies stderr" $
      modifyProg prog "stderr" (String "foo") `shouldBe`
      prog { stderr = Just "foo"}
    it "errors for non-string stderr" $
      evaluate (modifyProg prog "stderr" (Bool True)) `shouldThrow`
      anyErrorCall

    it "modifies directory" $
      modifyProg prog "directory" (String "foo") `shouldBe`
      prog { workingDir = Just "foo"}
    it "errors for non-string directory" $
      evaluate (modifyProg prog "directory" (Bool True)) `shouldThrow`
      anyErrorCall

    it "does nothing for all other cases" $
      modifyProg prog "bogus" (String "foo") `shouldBe`
      prog
  where prog = defaultProgram
