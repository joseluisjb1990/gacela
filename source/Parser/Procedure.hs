module Parser.Procedure
  ( listDefProc
  , function
  , funcParam
  , procedure
  , paramType
  , procParam
  ) where

-------------------------------------------------------------------------------
import           AST.Definition

import           Graciela
import           MyParseError        as PE
import           Parser.Assertion
import           Parser.Declaration
import           Parser.Expression
import           Parser.Instruction
import           Parser.Token
import           Parser.Type
import           Parser.State
import           Token
import           Type
-------------------------------------------------------------------------------
import qualified Control.Applicative as AP (liftA2)
import           Control.Monad       (void, liftM5, when)
import qualified Data.Text           as T
import           Data.Maybe          (catMaybes)
import           Text.Megaparsec     hiding (Token)
-------------------------------------------------------------------------------

listDefProc :: Graciela Token -> Graciela [Definition]
listDefProc follow = many (function <|> procedure)

function :: Graciela Definition
function  = do
    from <- getPosition
    do 
        match TokFunc
        id <- identifier
        newScopeParser
        params' <- parens . many $ funcParam id (match TokArrow)
        let params = catMaybes params'
        match TokArrow
        tname <- identifier
        retType <- getType tname
        when (retType == GError) $ syntaxError $ CustomError ("El tipo `"++T.unpack tname++"` no existe.")
        
        (match TokBegin)              
        pos <- getPosition 
        st <- getCurrentScope
        addFunTypeParser id params retType pos st
        body <- expression
        exitScopeParser
        addFunTypeParser id params retType pos st
        (match TokEnd) 

        to <- getPosition
        let func = (FunctionDef body retType)
        return $ Definition Location(from,to) id params st Nothing func
      -- <|> return (AST from from GError (EmptyAST))  


funcParam :: T.Text -> Graciela Token -> Graciela (Maybe (T.Text, Type))
funcParam idf follow =
    try ( do id <- identifier
             try ( do match TokColon
                      t  <- myType follow
                      pos <- getPosition
                      addFunctionArgParser idf id t pos
                      return $ Just (id, t)
                 )
                 <|> do genNewError follow PE.Colon
                        return Nothing
        )
        <|> do genNewError follow PE.IdError
               return Nothing

procedure :: {-Graciela Token -> Graciela Token ->-} Graciela Definition
procedure {-follow -} = do
    from <- getPosition
    match TokProc
    id <- identifier
    newScopeParser
    params' <- parens . many $ procParam id (match TokBegin)
    let params = catMaybes params'
    notFollowedBy $ match TokArrow
    try $do match TokBegin
    decls <- decListWithRead (match TokLeftPre)
    pre   <- precondition $ match TokOpenBlock
    body  <- block (match TokLeftPost)
    post  <- postcondition $ match TokEnd
    match TokEnd
    st   <- getCurrentScope
    addProcTypeParser id params from st
    exitScopeParser
    addProcTypeParser id params from st
    to <- getPosition
    let proc = (ProcedureDef decls pre body post)
    return $ Definition Location(from,to) id params st Nothing proc


paramType :: Graciela (Maybe TypeArg)
paramType = do  
        match TokIn
        return (Just $ In)
  <|> do 
        match TokInOut
        return (Just $ InOut)
  <|> do
        match TokOut
        return (Just $ Out)
  <|> do 
        match TokRef
        return (Just $ Ref)
  <|> return Nothing

procParam :: T.Text -> Graciela Token -> Graciela (Maybe (T.Text, Type))
procParam pid follow =
    do at <- paramType
       try (
         do id  <- identifier
            match TokColon
            t   <- myType follow
            pos <- getPosition
            addArgProcParser id pid t pos at
            return $ Just (id, t)
           )
           <|> do genNewError follow PE.IdError
                  return Nothing

-- Deberian estar en el lugar adecuando, hasta ahora aqui porq no le he usado en archivos q no dependen de Procedure

-- panicModeId :: Graciela Token -> Graciela T.Text
-- panicModeId token follow =
--         try identifier
--     <|> do t <- lookAhead follow
--            genNewError (return t) PE.IdError
--            return $ T.pack "No Id"
--     <|> do (t:_) <- anyToken `manyTill` lookAhead follow
--            genNewError (return $fst t) PE.IdError
--            return $ T.pack "No Id"


-- panicMode :: Graciela Token -> Graciela Token -> ExpectedToken -> Graciela ()
-- panicMode token follow err =
--         try (void token)
--     <|> do t <- lookAhead follow
--            genNewError (return t) err
--     <|> do (t:_) <- anyToken `manyTill` lookAhead follow
--            genNewError (return $ fst t) err
