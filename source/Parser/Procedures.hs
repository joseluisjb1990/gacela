module Parser.Procedures
  ( arg
  , argFunc
  , argumentType
  , followTypeFunction
  , function
  , listArgFunc
  , listArgFuncAux
  , listArgProc
  , listArgProcAux
  , listDefProc
  , panicMode
  , panicModeId
  , proc
  , procOrFunc
  ) where

-------------------------------------------------------------------------------
import           AST
import           Contents
import           Graciela
import           MyParseError        as PE
import           Parser.Assertions
import           Parser.Declarations
import           Parser.Expression
import           Parser.Instructions
import           Parser.Token
import           Parser.Type
import           ParserState
import           Token
import           Type
-------------------------------------------------------------------------------
import qualified Control.Applicative as AP (liftA2)
import           Control.Monad       (void, liftM5)
import qualified Data.Text           as T
import           Text.Megaparsec
-------------------------------------------------------------------------------

listDefProc :: Graciela Token -> Graciela Token -> Graciela (Maybe [AST Type])
listDefProc follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> do pf <- procOrFunc  follow recSet
              rl <- listDefProc follow recSet
              return (liftA2 (:) pf rl)
       <|> return Nothing


procOrFunc :: Graciela Token -> Graciela Token -> Graciela (Maybe (AST Type) )
procOrFunc follow recSet =
    try $ do
        lookAhead (parseProc <|> parseTokId)
        proc

    <|> try (do lookAhead (parseFunc <|> parseTokId)
                function (follow <|> parseFunc <|> parseProc) recSet)
    <|> do genNewError (follow <|> parseFunc <|> parseProc) PE.ProcOrFunc
           do lookAhead follow
              return Nothing
           <|> do lookAhead (parseProc <|> parseFunc)
                  procOrFunc follow recSet
                  return Nothing

                  -- choice [function (follow) recSet, proc]
                  --         <|> do parseEnd
                  --                return Nothing


followTypeFunction :: Graciela Token
followTypeFunction = parseTokOpenBlock <|> parseTokLeftBound


function :: Graciela Token -> Graciela Token -> Graciela (Maybe (AST Type) )
function follow recSet = do
    pos <- getPosition

    do match TokFunc
        <|> do try $ do t <- parseId
                        lookAhead parseId
                        genNewError (return $ TokId t) PE.ProcOrFunc
        <|> do t <- lookAhead parseId
               genNewError (return $ TokId t) PE.ProcOrFunc
        <|> do (t:_) <- manyTill anyToken (lookAhead parseId)
               genNewError (return $ fst t) PE.ProcOrFunc

    id <- panicModeId parseColon                                            -- Id
    -- panicMode parseColon parseLeftParent PE.Colon                           -- :
    panicMode parseLeftParent (parseTokId <|> parseTokRightPar) PE.TokenLP  -- (
    newScopeParser
    lt <- listArgFunc id parseTokRightPar parseTokRightPar                  -- arguments
    panicMode parseTokRightPar parseTokLeftPre PE.TokenRP                   -- )

    try $do match TokArrow
     <|> do t <- lookAhead parseType'
            genNewError (return $ TokType t) PE.Arrow
     <|> do (t:_) <- manyTill  anyToken (lookAhead parseType')
            genNewError (return $fst t) PE.Arrow

    t <- try $do parseType'
     <|> do t <- lookAhead parseBegin
            genNewError (return t) PE.TokenType
            return GUndef
     <|> do (t:_) <- manyTill  anyToken (lookAhead parseBegin)
            genNewError (return $fst t) PE.TokenType
            return GUndef

    try $do match TokBegin
     <|> do (t,_) <- lookAhead anyToken                                     -- func id : (in a :int) -> int
            genNewError (return t) PE.Begin                                 --                               ^
     <|> do (t:_) <- manyTill anyToken (lookAhead conditionalOrExpr)        -- func id : (in a :int) -> int [][]
            genNewError (return $fst t) PE.Begin                            --                              ^^^^

    sb <- getCurrentScope
    addFunTypeParser id lt t pos sb
    b <- conditionalOrExpr
    exitScopeParser
    addFunTypeParser id lt t pos sb

    try $do parseEnd
            return(liftM5 (DefFun id sb pos) b (return t) (Just (EmptyAST GEmpty)) lt (return GEmpty))
     <|> do genNewError follow PE.LexEnd
            return Nothing
    where
        conditionalOrExpr = conditional CExpression parseEnd parseEnd <|> (expr parseEnd parseEnd)
        parseType' :: Graciela Type
        parseType' = myType followTypeFunction followTypeFunction

   -- do pos <- getPosition
   --    try ( do parseFunc
   --             try ( do id <- parseId
   --                      try ( do parseColon
   --                               try ( do parseLeftParent
   --                                        newScopeParser
   --                                        lt <- listArgFunc id parseTokRightPar (recSet <|> parseTokRightPar)
   --                                        try ( do parseTokRightPar
   --                                                 try ( do parseArrow
   --                                                          t  <- myType (followTypeFunction) (recSet <|> followTypeFunction)
   --                                                          sb <- getCurrentScope
   --                                                          addFunTypeParser id lt t pos sb
   --                                                          b  <- functionBody follow follow
   --                                                          exitScopeParser
   --                                                          addFunTypeParser id lt t pos sb
   --                                                          return(liftM5 (DefFun id sb pos) b (return t) (Just (EmptyAST GEmpty)) lt (return GEmpty))
   --                                                     )
   --                                                     <|> do genNewError follow PE.Arrow
   --                                                            return Nothing
   --                                            )
   --                                            <|> do genNewError follow PE.TokenRP
   --                                                   return Nothing
   --                                   )
   --                                   <|> do genNewError follow PE.TokenLP
   --                                          return Nothing
   --                          )
   --                          <|> do genNewError follow PE.Colon
   --                                 return Nothing
   --                 )
   --                 <|> do genNewError follow PE.IdError
   --                        return Nothing
   --        )
   --        <|> do genNewError follow PE.TokenFunc
   --               return Nothing


listArgFunc :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe [(T.Text, Type)])
listArgFunc idf follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> do ar <- argFunc idf (follow <|> parseComma) (recSet <|> parseComma)
              rl <- listArgFuncAux idf follow recSet
              return(liftA2 (:) ar rl)


argFunc :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe (T.Text, Type))
argFunc idf follow recSet =
    try ( do id <- parseId
             try ( do parseColon
                      t  <- myType follow follow
                      pos <- getPosition
                      addFunctionArgParser idf id t pos
                      return $ return (id, t)
                 )
                 <|> do genNewError follow PE.Colon
                        return Nothing
        )
        <|> do genNewError follow PE.IdError
               return Nothing


listArgFuncAux :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe [(T.Text, Type)])
listArgFuncAux idf follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> try ( do parseComma
                    ar <- argFunc idf (follow <|> parseComma) (recSet <|> parseComma)
                    rl <- listArgFuncAux idf follow recSet
                    return(liftA2 (:) ar rl)
               )
               <|> do genNewError follow PE.Comma
                      return Nothing

proc :: {-Graciela Token -> Graciela Token ->-} Graciela (Maybe (AST Type) )
proc {-follow recSet-} = do
    pos <- getPosition

    match TokProc
        <|> do try $ do t <- parseId
                        lookAhead parseId
                        genNewError (return $TokId t) PE.ProcOrFunc
        <|> do t <- lookAhead parseId
               genNewError (return $TokId t) PE.ProcOrFunc
        <|> do (t:_) <- manyTill anyToken (lookAhead parseId)
               genNewError (return $fst t) PE.Begin                            -- proc

    id <- panicModeId parseColon                                            -- Id
    -- panicMode parseColon parseLeftParent PE.Colon                           -- :
    panicMode parseLeftParent (argTypes <|> parseTokRightPar) PE.TokenLP    -- (
    newScopeParser
    targs <- listArgProc id parseTokRightPar parseTokRightPar               -- arguments
    panicMode parseTokRightPar parseTokLeftPre PE.TokenRP                   -- )
    notFollowedBy parseArrow
    try $do match TokBegin
     <|> do t <- lookAhead $ parseVar <|> parseTokLeftPre
            genNewError (return t) PE.Begin                                 -- begin
     <|> do (t:_) <- manyTill anyToken (lookAhead $
                               parseVar <|> parseTokLeftPre)
            genNewError (return $fst t) PE.Begin
    dl   <- decListWithRead parseTokLeftPre parseTokLeftPre                 -- declarations
    pre  <- precondition parseTokOpenBlock                                  -- pre
    la   <- block parseTokLeftPost parseTokLeftPost                         -- body
    post <- postcondition parseEnd                                          -- post
    try $do match TokEnd
     <|> do (t,_) <- lookAhead anyToken
            genNewError (return t) PE.LexEnd
    sb <- getCurrentScope
    addProcTypeParser id targs pos sb
    exitScopeParser
    addProcTypeParser id targs pos sb
    return $ liftM5 (DefProc id sb) la pre post (Just (EmptyAST GEmpty)) dl
                <*> targs <*> return GEmpty
    where
        argTypes :: Graciela Token
        argTypes = choice   [ parseIn
                            , parseOut
                            , parseInOut
                            , parseRef
                            ]


    -- do pos <- getPosition
    --    try (
    --       do parseProc
    --          try (
    --            do id <- parseId
    --               try (
    --                 do parseColon
    --                    try (
    --                      do parseLeftParent
    --                         newScopeParser
    --                         targs <- listArgProc id parseTokRightPar parseTokRightPar
    --                         try (
    --                           do parseTokRightPar
    --                              try (
    --                                do parseBegin
    --                                   dl   <- decListWithRead parseTokLeftPre (parseTokLeftPre <|> recSet)
    --                                   pre  <- precondition parseTokOpenBlock
    --                                   la   <- block parseTokLeftPost parseTokLeftPost
    --                                   post <- postcondition parseEnd
    --                                   try (
    --                                     do parseEnd
    --                                        sb   <- getCurrentScope
    --                                        addProcTypeParser id targs pos sb
    --                                        exitScopeParser
    --                                        addProcTypeParser id targs pos sb
    --                                        return $ (liftM5 (DefProc id sb) la pre post (Just (EmptyAST GEmpty)) dl) <*> targs <*> (return GEmpty)
    --                                       )
    --                                       <|> do genNewError follow PE.LexEnd
    --                                              return Nothing
    --                                   )
    --                                   <|> do genNewError follow PE.Begin
    --                                          return Nothing
    --                              )
    --                              <|> do genNewError follow PE.TokenRP
    --                                     return Nothing
    --                         )
    --                         <|> do genNewError follow PE.TokenLP
    --                                return Nothing
    --                    )
    --                    <|> do genNewError follow PE.Colon
    --                           return Nothing
    --               )
    --               <|> do genNewError follow PE.IdError
    --                      return Nothing
    --        )
    --        <|> do genNewError follow PE.ProcOrFunc
    --               return Nothing

listArgProc :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe [(T.Text, Type)])
listArgProc id follow recSet =do
    try $do lookAhead follow
            return $ return []
     <|> do lookAhead parseEOF
            return Nothing
     <|> do ar <- arg id (follow <|> parseComma) (recSet <|> parseComma) `sepBy` parseComma
            return (Just $ foldr aux [] ar)
      where
          aux Nothing  l = l
          aux (Just x) l = x:l


listArgProcAux :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe [(T.Text, Type)])
listArgProcAux id follow recSet =
    do lookAhead follow
       return $ return []
       <|> do lookAhead parseEOF
              return Nothing
       <|> try (
             do parseComma
                ar <- arg id (follow <|> parseComma) (recSet <|> parseComma)
                rl <- listArgProcAux id follow recSet
                return(liftA2 (:) ar rl)
               )
               <|> do genNewError follow PE.Comma
                      return Nothing


argumentType :: Graciela Token -> Graciela Token -> Graciela (Maybe TypeArg)
argumentType follow recSet =
    do lookAhead (parseIn <|> parseOut <|> parseInOut <|> parseRef)
       do parseIn
          return (return In)
          <|> do parseOut
                 return (return Out)
          <|> do parseInOut
                 return (return InOut)
          <|> do parseRef
                 return (return Ref)
    <|> do genNewError follow TokenArg
           return Nothing


arg :: T.Text -> Graciela Token -> Graciela Token -> Graciela (Maybe (T.Text, Type))
arg pid follow recSet =
    do at <- argumentType parseTokId (recSet <|> parseTokId)
       try (
         do id  <- parseId
            parseColon
            t   <- myType follow recSet
            pos <- getPosition
            addArgProcParser id pid t pos at
            return $ return (id, t)
           )
           <|> do genNewError follow PE.IdError
                  return Nothing

-- Deberian estar en el lugar adecuando, hasta ahora aqui porq no le he usado en archivos q no dependen de Procedure

panicModeId :: Graciela Token -> Graciela T.Text
panicModeId follow =
        try parseId
    <|> do t <- lookAhead follow
           genNewError (return t) PE.IdError
           return $ T.pack "No Id"
    <|> do (t:_) <- anyToken `manyTill` lookAhead follow
           genNewError (return $fst t) PE.IdError
           return $ T.pack "No Id"


panicMode :: Graciela Token -> Graciela Token -> ExpectedToken -> Graciela ()
panicMode token follow err =
        try (void token)
    <|> do t <- lookAhead follow
           genNewError (return t) err
    <|> do (t:_) <- anyToken `manyTill` lookAhead follow
           genNewError (return $ fst t) err
