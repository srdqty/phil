module Delete (
      deleteItem
    , deleteAll 
) where

import Data.List hiding (find, delete)
import Data.Text (pack, unpack)
import Database.MongoDB

import Utils
import Get


deleteItem :: DatabaseName -> [String] -> IO [String]
deleteItem dbName args = do
    pipe <- sharedPipe
    let docType = getDocType $ head args
        n = read (args !! 1) :: Int
    run pipe dbName $ find (select [] (docTypeToText docType))
            >>= rest >>= (del pipe docType n)
    return []

del :: Pipe -> DocType -> Int -> [Document] -> Action IO ()
del pipe docType n docs = do
    let collection = docTypeToText docType
    let ObjId itemId = valueAt (pack "_id") (docs !! (n-1))
    deleteOne (select [(pack "_id") =: itemId] collection)
    --get ProdDB [(unpack $ docTypeToText docType)]
    --return ()

-- | Delete all documents of a certain type from db
deleteAll :: DatabaseName -> DocType -> IO [String]
deleteAll dbName docType = do
    pipe <- sharedPipe
    e <- access pipe master (pack $ databaseNameToString dbName)
        $ delete (select [] (docTypeToText docType))
    return []
