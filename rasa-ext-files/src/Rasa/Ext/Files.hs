{-# LANGUAGE TemplateHaskell #-}

module Rasa.Ext.Files
  ( files
  , save
  ) where

import qualified Data.Text.IO as TIO
import Control.Lens
import System.Environment

import Data.String (fromString)
import Data.Typeable
import Data.Default 

import Control.Monad.IO.Class
import qualified Data.Text as T

import Rasa.Ext
import Rasa.Ext.StatusBar
import Rasa.Ext.Directive
import Rasa.Ext.Scheduler

data FileInfo = FileInfo
  { _filename :: Maybe String
  } deriving (Typeable, Show, Eq)

makeLenses ''FileInfo

instance Default FileInfo where
  def = FileInfo {
  _filename=Nothing
}

files :: Scheduler ()
files = do
  onInit loadFiles
  beforeRender showFilename

showFilename :: Action ()
showFilename = focusDo $ do
  fname <- use $ bufExt.filename
  case fname of
    Just fname' -> leftStatus $ T.pack ("<" ++ fname' ++ ">")
    Nothing -> return ()

save :: BufAction ()
save = do
  txt <- use text
  fname <- use $ bufExt.filename
  liftIO $ sequence_ $ TIO.writeFile <$> fname <*> pure txt

setFilename :: String -> BufAction ()
setFilename fname = bufExt .= FileInfo (Just fname)

addFile :: String -> T.Text -> Action ()
addFile fname txt = addBufferThen txt (setFilename fname)

loadFiles :: Action ()
loadFiles = do
  fileNames <- liftIO getArgs
  fileTexts <- liftIO $ traverse (TIO.readFile . fromString) fileNames
  mapM_ (uncurry addFile) $ zip fileNames fileTexts
