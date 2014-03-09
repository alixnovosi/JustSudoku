module Main where

import Graphics.UI.Gtk
import Control.Monad.Trans(liftIO)
import Control.Monad(replicateM)
import Data.Maybe
import Control.DeepSeq

-- Get count entries
getEntryRow :: Int -> IO [Entry]
getEntryRow count = do
    entry <- entryNew
    row <- replicateM (count - 1)  $ do
        entry <- entryNew
        return entry
    return $ entry : row

-- Get entry grid, size count x count
getEntryGrid :: Int -> IO [[Entry]]
getEntryGrid count = do
    entryRow <- getEntryRow count
    grid <- replicateM (count - 1) $ do
        entryRow <- getEntryRow count
        return entryRow
    return $ entryRow : grid

-- Pack an entry given the entry, a table to pack in, and coordinates.
packEntry :: (TableClass self) => self -> Entry -> (Int, Int) -> (Int, Int) -> IO ()
packEntry table entry colCoords rowCoords = do
    tableAttachDefaults table entry colT colB rowL rowR
    where
        rowL = fst rowCoords
        rowR = snd rowCoords
        colT = fst colCoords
        colB = snd colCoords

-- Pack a 1D list of widgets into a table with the provided indices.
packEntryList :: (TableClass self) => self -> [Entry] -> [(Int, Int)] -> [(Int, Int)] -> IO [()]
packEntryList table entryArray colCoords rowCoords = do
    sequence $ zipWith3 (packEntry table) entryArray colCoords rowCoords

-- Pack a 2D list of entries with the provided indices.
packAllEntries :: (TableClass self) => self -> [[Entry]] -> [[(Int, Int)]] -> [[(Int, Int)]] -> IO [[()]]
packAllEntries table entryArray colCoords rowCoords = do
    sequence $ zipWith3 (packEntryList table) entryArray colCoords rowCoords

-- Convert from int to string, discarding out of range.
checkValue :: String -> Maybe Int
checkValue "1" = Just 1
checkValue "2" = Just 2
checkValue "3" = Just 3
checkValue "4" = Just 4
checkValue "5" = Just 5
checkValue "6" = Just 6
checkValue "7" = Just 7
checkValue "8" = Just 8
checkValue "9" = Just 9
checkValue _   = Nothing

-- Adds an int to a tuple of ints.
addToTuple :: Int -> (Int, Int) -> (Int, Int)
addToTuple num oldTuple = ((fst oldTuple) + num, (snd oldTuple) + num)

-- Add int to tuple of int if two conditions are true.
addToTupleIf :: Int -> (Int -> Bool) -> (Int ->Bool) -> (Int, Int) -> (Int, Int)
addToTupleIf new fstCond sndCond (f, s) = result
    where condition = fstCond f && sndCond s
          result    = if condition then (f + new, s + new) else (f, s)

-- Special case for adding one to tuple.
incrementTupleIf :: (Int -> Bool) -> (Int -> Bool) -> (Int, Int) -> (Int, Int)
incrementTupleIf fstCond sndCond oldTuple = addToTupleIf 1 fstCond sndCond oldTuple

-- Checks whether an entry is between 1 and 9 inclusive and
-- discards it otherwise.
validateEntry :: Entry -> IO ()
validateEntry e = do
    txt <- entryGetText e

    if length txt == 0
        then do
        entrySetText e ""
        else if isJust $ checkValue txt
            then do 
                let validated = checkValue txt
                    newtxt    = show $ fromJust validated
                entrySetText e newtxt
            else do
                entrySetText e $ show 1

-- Generate column coordinates for a 9x9 Sudoku grid. 
colCoords :: [[(Int, Int)]]
colCoords = final
    where oneRow  = [(x, x + 1) | x <- [0..8]] :: [(Int, Int)]
          filter1 = map (incrementTupleIf (>2) (>2)) oneRow
          filter2 = map (incrementTupleIf (>6) (>6)) filter1
          final   = replicate 9 filter2 :: [[(Int, Int)]]

-- Generate row coordinates for a 9x9 Sudoku grid.
rowCoords :: [[(Int, Int)]]
rowCoords = final
    where oneRow  = [(x, x + 1) | x <- [0..8]] :: [(Int, Int)]
          filter1 = map (incrementTupleIf (>2) (>2)) oneRow
          filter2 = map (incrementTupleIf (>6) (>6)) filter1
          final   = map (replicate 9) filter2 :: [[(Int, Int)]] 

-- Add validate function to all entries.
addValidateFunction :: [[Entry]] -> IO [[ConnectId Entry]]
addValidateFunction entryArray = do
    sequence $ map (\row -> validateOne row) entryArray
    where
        validateOne row = sequence $ map (\entry -> onEntryActivate entry (validateEntry entry)) row

main = do
    
    -- Init GUI and window handle.
    initGUI
    window    <- windowNew
    mainBox   <- vBoxNew False 10
    table     <- tableNew 10 10 True

    menuBar   <- menuBarNew

    -- Grid fields.
    entryGrid <- getEntryGrid 9
    
    checkItem    <- menuItemNewWithMnemonic "_Check"
    solveItem    <- menuItemNewWithMnemonic "_Solve"
    mainMenuItem <- menuItemNewWithMnemonic "_Main Menu"

    -- Add items to menu
    menuShellAppend menuBar mainMenuItem
    menuShellAppend menuBar checkItem
    menuShellAppend menuBar solveItem

    --entrySetMaxLength ((entryGrid !! 0) !! 1) 1
   
    -- Apply some functions to the entries.
    addValidateFunction entryGrid

    -- Pack entries.
    packAllEntries table entryGrid colCoords rowCoords

    -- Set window parameters.
    set window [windowDefaultWidth := 200
               , windowDefaultHeight := 200
               , windowTitle := "Sudoku Linux"
               , containerChild := mainBox
               , containerBorderWidth := 10]
    
    -- Pack some other stuff.           
    boxPackStart mainBox menuBar PackNatural 0
    boxPackStart mainBox table PackGrow 0
    
    onDestroy window mainQuit
    widgetShowAll window
    mainGUI

