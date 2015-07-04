{-# LANGUAGE ScopedTypeVariables #-}
module Angel.PidFileSpec (spec) where

import Angel.PidFile

import Control.Exception.Base ( try
                              , SomeException )
import Data.Char (isNumber)
import Data.IORef ( newIORef
                  , readIORef
                  , writeIORef )
import System.Process (proc)
import System.Posix.Files (fileExist)

import SpecHelper

spec :: TestTree
spec = testGroup "Angel.PidFile"
  [
    testGroup "startWithPidFile"
    [
      testCase "creates the pidfile and cleans up" $ do
        startWithPidFile procSpec fileName jogOn $ \_pHandle -> do
          fileShouldExist fileName
          pid <- readFile fileName
          null pid @?= False
          all isNumber pid @?= True
        fileShouldNotExist fileName
    , testCase "calls the error callback when pidfile can't be created and re-raises" $ do
        called <- newIORef False
        let onPidError = const $ writeIORef called True
        (res :: Either SomeException ()) <- try $ startWithPidFile procSpec badPidFile jogOn onPidError
        readIORef called `shouldReturn` True
        isLeft res @?= True
    ]
  ]
  where
    fileName = "temp.pid"
    badPidFile = "/bogus/path/to/pidfile"
    procSpec = proc "pwd" []
    fileShouldExist _name    = fileExist fileName `shouldReturn` True
    fileShouldNotExist _name = fileExist fileName `shouldReturn` False
    jogOn = const $ return ()
    isLeft (Left _) = True
    isLeft _        = False
