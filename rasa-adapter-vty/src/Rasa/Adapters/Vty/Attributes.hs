{-# LANGUAGE OverloadedStrings #-}
module Rasa.Adapters.Vty.Attributes where

import Rasa.Ext.Style
import qualified Data.Text as T
import qualified Graphics.Vty as V
import Data.List (unfoldr)
import Control.Arrow (first)

type AttrList = [(Int, V.Attr)]

convertIStyle :: IStyle -> (Int, V.Attr)
convertIStyle (IStyle i a) = (i, convertAttr a)

convertAttr :: Style -> V.Attr
convertAttr (Style (fg', bg', flair')) = V.Attr
                                        (maybe V.KeepCurrent convertFlair flair')
                                        (maybe V.KeepCurrent convertColor fg')
                                        (maybe V.KeepCurrent convertColor bg')

convertFlair :: Flair -> V.MaybeDefault V.Style
convertFlair Standout = V.SetTo V.standout
convertFlair Underline = V.SetTo V.underline
convertFlair ReverseVideo = V.SetTo V.reverseVideo
convertFlair Blink =  V.SetTo V.blink
convertFlair Dim = V.SetTo  V.dim
convertFlair Bold = V.SetTo V.bold
convertFlair DefFlair = V.Default

convertColor :: Color -> V.MaybeDefault V.Color
convertColor Black = V.SetTo V.black
convertColor Red = V.SetTo V.red
convertColor Green = V.SetTo V.green
convertColor Yellow = V.SetTo V.yellow
convertColor Blue = V.SetTo V.blue
convertColor Magenta = V.SetTo V.magenta
convertColor Cyan = V.SetTo V.cyan
convertColor White = V.SetTo V.white
convertColor DefColor = V.Default

reset :: V.Image
reset = V.text' V.defAttr ""

applyAttrs :: [(Int, V.Attr)] -> T.Text -> V.Image
applyAttrs atts t = applyAttrs' atts (T.lines t)

applyAttrs' :: AttrList -> [T.Text] -> V.Image
applyAttrs' atts lines' = vertCat $ unfoldr attrLines (atts, lines')
  where
    vertCat = foldr ((V.<->) . (V.<|> reset)) V.emptyImage
    attrLines :: (AttrList, [T.Text]) -> Maybe (V.Image, (AttrList, [T.Text]))
    attrLines (_, []) = Nothing
    attrLines (as, l:ls) = let (img, restAs) = attrLine as l
                     in Just (img, (decr 1 restAs, ls))

-- Should be able to clean this up and provide better guarantees if I do a scan
-- over attrs and get each successive mappend of them, then do T.splitAt for
-- each offset, then apply the attr for each section at the begining of each
-- of T.lines within each group. Ugly I know.
attrLine :: AttrList -> T.Text -> (V.Image, AttrList)
attrLine [] txt = (plainText txt, [])
attrLine ((0, attr):atts) txt = first (V.text' attr "" V.<|>) $ attrLine atts txt
attrLine atts "" = (V.emptyImage, atts)
attrLine allAttrs@((offset, _):_) txt
  -- If the offset is larger, we can add the whole line, then decrement the attr offsets
  | offset > T.length txt = (plainText txt, decr (T.length txt) allAttrs)
  -- The offset occurs within the line, apply it in the middle
  | otherwise = first (prefix V.<|>) suffix
  where prefix = plainText (T.take offset txt)
        suffix = attrLine (decr offset allAttrs) (T.drop offset txt)

decr :: Int -> AttrList -> AttrList
decr n = fmap $ first (subtract n)

plainText :: T.Text -> V.Image
plainText = V.text' V.currentAttr
