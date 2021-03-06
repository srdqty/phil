{-# LANGUAGE OverloadedStrings #-}

module Tests (
  main
) where

import Data.Char
import Control.Monad
import System.IO
import System.Directory
import Test.HUnit     
import Test.QuickCheck
import Database.MongoDB
import Data.Int
import Data.Time.Format.Human
import Data.Text (pack)

import Utils
import Validate
import Add
import Delete
import Get
import Review
import Done
import Main hiding (main)

todoCases = TestLabel "Todo test cases" (TestList [
   testDeleteTodo, 
   testGetTodoPriorityOne,
   testGetTodoByDay,
   testGetTodoTags, 
   testGetTwoTodoTags,
   testGetFieldsForTodo,
   testGetTodoFromPriorityAndTag,
   testDisplayTodoTags,
   testDisplayTodoWithTags,
   testCompleteTodo])

noteCases = TestLabel "Note test cases" (TestList [
  testNoteIsValid1, testNoteIsValid2, testGetNoteByTag, testDeleteNote,
  testNoteCreatedTime, testGetNoteTags])

flashcardCases = TestLabel "Flashcard test cases" (TestList [
  testFlashcardIsValid1, testFlashcardIsValid2, testReview, 
  testReverseFlashcards])

scoreCases = TestLabel "Score test cases" (TestList [
  testIncrementTestCountOnce, testIncrementTestCountTwice])

main = runTestTT $ TestList [todoCases, noteCases, flashcardCases, scoreCases]

-- 
-- Validating items
-- 

testNoteIsValid1 = TestCase $ assertEqual "Note should be invalid" False 
  (noteIsValid ["invalid", "no", "uppercase"])
testNoteIsValid2 = TestCase $ assertEqual "Note should be valid" True
  (noteIsValid ["uppercase", "Valid"])

testFlashcardIsValid1 = TestCase $ assertEqual "Flashcard should be invalid" 
  False (flashcardIsValid ["invalid", "No", "question", "mark"])
testFlashcardIsValid2 = TestCase $ assertEqual "Flashcard should be valid"
  True (flashcardIsValid ["uppercase", "Question?", "yes"])

testGetQuestion = TestCase $ assertEqual "Should get question" 
  "Why is the sky blue" $ getQuestion "Why is the sky blue? just cuz."

testGetAnswer = TestCase $ assertEqual "Should get answer" 
  "just cuz." $ getAnswer "Why is the sky blue? just cuz."

-- 
-- Displaying items
--

testNoteCreatedTime = TestCase (do
  deleteAll Note
  add TestDB Note ["Newfangled", "technique"]
  results <- get TestDB ["notes", "created"]
  case results of
    [] -> assertFailure "Didn't get any notes from the DB"
    string:[] -> assertEqual "The note should display the created time"
      "1 - just now - Newfangled technique" string)

testDisplayTodoTags = TestCase (do
  deleteAll Todo
  add TestDB Todo ["255", "Code some assignment"]
  add TestDB Todo ["228", "Finish pset"]
  add TestDB Todo ["228", "Read book"]
  results <- get TestDB ["todo", "tags"]
  case results of 
    [] -> assertFailure "Didn't get any todo tags"
    x:xs -> assertEqual "There should be two todo tags"
      ("2 228", "1 255") (x, head xs))

testDisplayTodoWithTags = TestCase (do
  deleteAll Todo
  add TestDB Todo ["255", "Code some assignment"]
  add TestDB Todo ["228", "school", "Finish pset"]
  results <- get TestDB ["todo", "with", "tags"]
  case results of 
    [] -> assertFailure "Didn't get any todos with tags"
    x:xs -> assertEqual "There should be two todos with tags"
      ("1 - [255] - Code some assignment", "2 - [228, school] - Finish pset") 
        (x, head xs))
-- 
-- Deleting items
-- 

testDeleteTodo = TestCase (do
  deleteAll Todo
  add TestDB Todo ["tag1", "First", "shimmer"]
  add TestDB Todo ["second", "Here"]
  add TestDB Todo ["tag2", "Third"]
  get TestDB ["todo"]
  deleteItem TestDB 2
  results <- get TestDB ["todo"]
  case results of 
    [] -> assertFailure "Didn't get any todos from the DB"
    strings -> assertEqual "The second todo should have been deleted" 
      (2, "1 - First shimmer", "2 - Third")
        (length strings, head strings, strings !! 1))

testDeleteNote = TestCase (do
  deleteAll Note
  add TestDB Note ["tag2", "First", "glitter"]
  add TestDB Note ["second", "Bubbles"]
  add TestDB Note ["tag2", "Third"]
  get TestDB ["note", "tag2"]
  deleteItem TestDB 2
  results <- get TestDB ["note"]
  case results of 
    [] -> assertFailure "Didn't get any notes from the DB"
    strings -> assertEqual "The second note should have been deleted" 
      (2, "1 - First glitter", "2 - Bubbles")
        (length strings, head strings, strings !! 1))

--
-- Todo prorities
--

testGetTodoPriorityOne = TestCase (do
  deleteAll Todo
  add TestDB Todo ["tag1", "p1", "First", "hi"]
  add TestDB Todo ["tag1", "p2", "Second", "here"]
  add TestDB Todo ["tag1", "Third", "here"]
  results <- get TestDB ["todo", "p1"]
  case results of 
    [] -> assertFailure
      "Didn't get any results after adding todo with priority 1" 
    strings -> assertEqual "There should be only one todo with priority 1" 
      1 (length strings))

testGetTodoByDay = TestCase (do
  deleteAll Todo
  add TestDB Todo ["tag1", "p1", "by", "12/21", "First", "penguin"]
  add TestDB Todo ["tag1", "p2", "by", "12/22", "Second", "here"]
  add TestDB Todo ["tag2", "p2", "Third", "here"]
  results <- get TestDB ["todo", "by", "12/21"]
  case results of 
    [] -> assertFailure
      "Didn't get any results after adding todos with due dates"
    strings -> assertEqual "There should be two todos due by 12/22"
      1 (length strings))

-- TODO test this
testGetTodoByTomorrow = TestCase (do
  deleteAll Todo
  add TestDB Todo ["tag1", "p1", "by", "tomorrow", "First", "here", "heart"]
  add TestDB Todo ["tag2", "p2", "Third", "here"]
  results <- get TestDB ["todo", "tomorrow"]
  case results of 
    [] -> assertFailure
      "Didn't get any results after adding todos with due dates"
    strings -> assertEqual "There should be two todos due by 12/22"
      2 (length strings))

-- 
-- Tags
--

testGetTodoTags = TestCase (do
  deleteAll Todo
  add TestDB Todo ["p1", "First", "here", "crazy"]
  add TestDB Todo ["p2", "Second", "here"]
  add TestDB Todo ["water", "Third", "here"]
  results <- get TestDB ["todo", "water"]
  case results of 
    [] -> assertFailure 
      "Didn't get results after adding todo tagged 'water'"
    strings -> assertEqual "There should be only one todo tagged 'water'" 
      (1, "1 - Third here") (length strings, head strings))

testGetNoteTags = TestCase (do
  deleteAll Note
  add TestDB Note ["p1", "First", "canoe"]
  add TestDB Note ["p2", "Second", "here"]
  add TestDB Note ["water", "Third", "here"]
  results <- get TestDB ["note", "water"]
  case results of 
    [] -> assertFailure 
      "Didn't get results after adding note tagged 'water'"
    strings -> assertEqual "There should be only one note tagged 'water'" 
      (1, "1 - Third here") (length strings, head strings))

testGetTwoTodoTags = TestCase (do
  deleteAll Todo
  add TestDB Todo ["p1", "school", "First", "seven-hundred"]
  add TestDB Todo ["229", "Second", "here"]
  add TestDB Todo ["water", "229", "Third", "here"]
  results <- get TestDB ["todo", "water", "229"]
  case results of 
    [] -> assertFailure
      "Didn't get results after adding todo tagged 'water' and '229'"
    strings -> assertEqual 
      "There should be only one todo tagged 'water' and '229'" 
        (1, "1 - Third here") (length strings, head strings))

testGetFieldsForTodo = TestCase (do
  assertEqual "Should get a list of fields for matching two tags"
    [(labelStr Tags) =: [("school" :: String), ("229" :: String)],
      (labelStr TextLabel) =: ("First one" :: String)]
        (getFieldsForTodo [] ["school", "229", "First", "one"] []))

testGetTodoFromPriorityAndTag = TestCase (do
  deleteAll Todo
  add TestDB Todo ["p1", "school", "First", "snoopy"]
  add TestDB Todo ["school", "Second", "here"]
  add TestDB Todo ["p1", "Third", "here"]
  results <- get TestDB ["todo", "school", "p1"]
  case results of 
    [] -> assertFailure
      "Didn't get results after adding todo tagged 'school' and 'p1'"
    strings -> assertEqual
      "There should be only one todo tagged 'school' and 'p1'" 
        (1, "1 - First snoopy") (length strings, head strings))

testGetNoteByTag = TestCase (do
  deleteAll Note
  add TestDB Note ["music", "First", "here", "zoom"]
  add TestDB Note ["water", "Second", "here"]
  results <- get TestDB ["note", "water"]
  case results of
    [] -> assertFailure 
      "Didn't get results after adding note tagged 'water'"
    strings -> assertEqual
      "There should be only one note tagged 'water'"
        (1, "1 - Second here") (length strings, head strings))

testCompleteTodo = TestCase (do
  deleteAll Todo
  add TestDB Todo ["beach", "Bring sunscreen"] 
  add TestDB Todo ["beach", "Bring sunglasses"] 
  add TestDB Todo ["beach", "Bring towel"] 
  pipe <- sharedPipe
  completeTodo TestDB 2
  results <- get TestDB ["todo"]
  case results of 
    [] -> assertFailure
      "Didn't get results after adding todos and completing one"
    strings -> assertEqual 
      "There should be only two todos not completed"
        2 (length strings)
  results2 <- get TestDB ["todo", "done"]
  case results2 of 
    [] -> assertFailure
      "Didn't get results after adding todos and completing one"
    strings -> assertEqual 
      "There should be only one todo completed" 1 (length strings))

--
-- Flashcards
--

testReview = TestCase (do
  deleteAll Flashcard
  add TestDB Flashcard ["229", "lect1", "What", "is", "the", "maximum?", "20"]
  add TestDB Flashcard ["229", "lect1", "What", "is", "the", "minimum?", "-3"]
  add TestDB Flashcard ["229", "lect2", "What", "is", "the", "average?", "1"]
  pipe <- sharedPipe
  result <- review TestDB ["229"]
  assertEqual "The flashcards should be separated by two newlines"
    ("What is the maximum?\n    20\n\nWhat is the minimum?\n    -3"
      ++ "\n\nWhat is the average?\n    1\n\n") result)

testReverseFlashcards = TestCase (do
  deleteAll Flashcard
  add TestDB Flashcard ["229", "lect1", "What", "is", "the", "maximum?", "20"]
  add TestDB Flashcard ["229", "lect1", "What", "is", "the", "minimum?", "-3"]
  add TestDB Flashcard ["229", "lect2", "What", "is", "the", "average?", "1"]
  pipe <- sharedPipe
  docs <- getFlashcards TestDB ["229", "reverse"]
  assertEqual "The order of the retrieved flashcards should be reversed"
    (valueAt (labelStr Question) (head docs))
      (String (pack "What is the average")))

testIncrementTestCountOnce = TestCase (do
  deleteAll TestCount 
  incrementTestCount TestDB ["purple"]
  mInt <- getTestCount TestDB ["purple"]
  case mInt of
    Nothing -> assertFailure "Didn't increment the test count"
    Just i -> assertEqual "Incremented the test count once" 1 i)
     
testIncrementTestCountTwice = TestCase (do
  deleteAll TestCount 
  incrementTestCount TestDB ["purple"]
  incrementTestCount TestDB ["purple"]
  mInt <- getTestCount TestDB ["purple"]
  case mInt of
    Nothing -> assertFailure "Didn't increment the test count"
    Just i -> assertEqual "Incremented the test count twice" 2 i)

testTimeRangesAreValid = TestCase (do
  let shouldBeTrue = all isTimeRange
        ["5 - 6", "4am - 12pm", "4:32am - 3pm", "12:01 - 12:02",
          (unwords ["4:30pm", "-", "7pm"])]
  assertEqual "All these times should be valid" True shouldBeTrue)

testTimeRangesAreInvalid = TestCase (do
  let shouldBeFalse = any isTimeRange 
        ["5AM - 6", "4am - 12p", "4:61 - 3pm", "12:01", "4: - 3pm", "13 - 4",
          "4-5"]
  assertEqual "All these times should be invalid" False shouldBeFalse)

{-
testRecordLastGet = TestCase (do
  pipe <- sharedPipe 
  deleteAll LastGet
  recordGet TestDB "todo"
  result <- getLastGet TestDB
  assertEqual "Should be the last get" "todo" result 
  recordGet TestDB "todo mountain"
  result <- getLastGet TestDB
  assertEqual "Should be the last get" "todo mountain" result )

testFullRecordLastGet = TestCase (do
  pipe <- sharedPipe 
  deleteAll Todo
  deleteAll LastGet
  add TestDB Todo ["Fly", "to", "Verona"]
  add TestDB Todo ["Get", "tickets", "to", "see", "Kanye"]
  add TestDB Todo ["mountain", "Go", "skiing"]
  add TestDB Todo ["mountain", "Snowboard"]
  get TestDB ["todo", "mountain"]
  results <- get TestDB ["todo", "mountain"]
  assertEqual "There should be two todos tagged 'mountain'" 2 (length results)
  deleteItem TestDB 2
  results <- get TestDB ["todo", "mountain"]
  assertEqual "There should be 1 todo tagged 'mountain'" (1, "1 - Go skiing")
    ((length results), (head results))
  results <- get TestDB ["todo"]
  assertEqual "There suhold be two todos" 2 (length results)
  deleteItem TestDB 1
  results <- get TestDB ["todo"]
  putStrLn "WHAT"
  assertEqual "There should be 1 todo left" (1, "1 - Get tickets to see Kanye")
    ((length results), (head results)))
    -}
