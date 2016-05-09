module Parser where

import Control.Monad.Identity (Identity)
import qualified Control.Applicative as AP
import qualified Control.Monad       as M
import qualified Data.Text           as T
import MyParseError                  as PE
import ParserState
import Declarations
import Text.Parsec
import TokenParser
import Expression
import ParserType
import Data.Maybe
import Contents
import Location
import Token
import State
import Type
import AST


data CasesConditional = CExpression | CAction


program :: MyParser (Maybe (AST(Type)))
program = do pos <- getPosition
             newScopeParser
             try ( do parseProgram
                      try ( do id  <- parseID
                               try ( do parseBegin
                                        ast  <- listDefProc parseTokOpenBlock parseTokOpenBlock
                                        lacc <- block parseEnd parseEnd
                                        try ( do parseEnd
                                                 parseEOF
                                                 return (M.liftM3 (AST.Program id (toLocation pos)) ast lacc (return (GEmpty)))
                                            )
                                            <|> do genNewError parseEOF PE.LexEnd
                                                   return Nothing
                                   )
                                   <|> do genNewError parseEOF PE.Begin
                                          return Nothing
                          )
                          <|> do genNewError parseEOF PE.IDError
                                 return Nothing
                 )
                 <|> do genNewError parseEOF PE.Program
                        return Nothing

listDefProc :: MyParser Token -> MyParser Token -> MyParser (Maybe [AST(Type)])
listDefProc follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> do pf <- procOrFunc  follow recSet
              rl <- listDefProc follow recSet
              return (AP.liftA2 (:) pf rl)
       <|> do return $ Nothing


procOrFunc :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
procOrFunc follow recSet =
    do lookAhead parseFunc
       function (follow <|> parseFunc <|> parseProc) recSet
    <|> do lookAhead parseProc
           proc (follow <|> parseFunc <|> parseProc) recSet
    <|> do genNewError (follow <|> parseFunc <|> parseProc) PE.ProcOrFunc
           do lookAhead follow
              return Nothing
           <|> do lookAhead (parseProc <|> parseFunc)
                  procOrFunc follow recSet
                  return Nothing


followTypeFunction :: MyParser Token
followTypeFunction = parseTokOpenBlock <|> parseTokLeftBound


function :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
function follow recSet =
   do pos <- getPosition
      try ( do parseFunc
               try ( do id <- parseID
                        try ( do parseColon
                                 try ( do parseLeftParent
                                          newScopeParser
                                          lt <- listArgFunc id parseRightParent (recSet <|> parseRightParent)
                                          try ( do parseRightParent
                                                   try ( do parseArrow
                                                            t  <- myType (followTypeFunction) (recSet <|> followTypeFunction)
                                                            sb <- getActualScope
                                                            addFunTypeParser id lt t (toLocation pos) sb
                                                            b  <- functionBody follow follow
                                                            exitScopeParser
                                                            addFunTypeParser id lt t (toLocation pos) sb
                                                            return(M.liftM5 (DefFun id sb (toLocation pos)) b (return t) (Just (EmptyAST GEmpty)) lt (return (GEmpty)))
                                                       )
                                                       <|> do genNewError follow PE.Arrow
                                                              return Nothing
                                              )
                                              <|> do genNewError follow PE.TokenRP
                                                     return Nothing
                                     )
                                     <|> do genNewError follow PE.TokenLP
                                            return Nothing
                            )
                            <|> do genNewError follow PE.Colon
                                   return Nothing
                   )
                   <|> do genNewError follow PE.IDError
                          return Nothing
          )
          <|> do genNewError follow PE.TokenFunc
                 return Nothing


listArgFunc :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe [(T.Text, Type)])
listArgFunc idf follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> do ar <- argFunc idf (follow <|> parseComma) (recSet <|> parseComma)
              rl <- listArgFuncAux idf follow recSet
              return(AP.liftA2 (:) ar rl)


argFunc :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe (T.Text, Type))
argFunc idf follow recSet =
    try ( do id <- parseID
             try ( do parseColon
                      t  <- myType follow follow
                      pos <- getPosition
                      addFunctionArgParser idf id t (toLocation pos)
                      return $ return (id, t)
                 )
                 <|> do genNewError follow PE.Colon
                        return Nothing
        )
        <|> do genNewError follow PE.IDError
               return Nothing


listArgFuncAux :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe [(T.Text, Type)])
listArgFuncAux idf follow recSet =
    do lookAhead parseEOF
       return Nothing
       <|> do lookAhead follow
              return $ return []
       <|> try ( do parseComma
                    ar <- argFunc idf (follow <|> parseComma) (recSet <|> parseComma)
                    rl <- listArgFuncAux idf follow recSet
                    return(AP.liftA2 (:) ar rl)
               )
               <|> do genNewError follow PE.Comma
                      return Nothing

proc :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
proc follow recSet =
    do pos <- getPosition
       try (
          do parseProc
             try (
               do id <- parseID
                  try (
                    do parseColon
                       try (
                         do parseLeftParent
                            newScopeParser
                            targs <- listArgProc id parseRightParent parseRightParent
                            try (
                              do parseRightParent
                                 try (
                                   do parseBegin
                                      dl   <- decListWithRead parseTokLeftPre (parseTokLeftPre <|> recSet)
                                      pre  <- precondition parseTokOpenBlock (recSet <|> parseTokOpenBlock)
                                      la   <- block parseTokLeftPost parseTokLeftPost
                                      post <- postcondition parseEnd (recSet <|> parseEnd)
                                      try (
                                        do parseEnd
                                           sb   <- getActualScope
                                           addProcTypeParser id targs (toLocation pos) sb
                                           exitScopeParser
                                           addProcTypeParser id targs (toLocation pos) sb
                                           return $ (M.liftM5 (DefProc id sb) la pre post (Just (EmptyAST GEmpty)) dl) AP.<*> targs AP.<*> (return GEmpty)
                                          )
                                          <|> do genNewError follow PE.LexEnd
                                                 return Nothing
                                      )
                                      <|> do genNewError follow PE.Begin
                                             return Nothing
                                 )
                                 <|> do genNewError follow PE.TokenRP
                                        return Nothing
                            )
                            <|> do genNewError follow PE.TokenLP
                                   return Nothing
                       )
                       <|> do genNewError follow PE.Colon
                              return Nothing
                  )
                  <|> do genNewError follow PE.IDError
                         return Nothing
           )
           <|> do genNewError follow PE.ProcOrFunc
                  return Nothing

assertions initial final ty follow =
    try (
      do initial
         e <- expr final (follow <|> final)
         try (
           do final
              pos <- getPosition
              return $ AP.liftA2 (States ty (toLocation pos)) e (return (GEmpty))
             )
             <|> do genNewError follow PE.TokenCA
                    return Nothing
         )
         <|> do genNewError follow PE.TokenOA
                return Nothing

precondition :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
precondition follow recSet = assertions parseTokLeftPre parseTokRightPre Pre follow

postcondition :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
postcondition follow recSet = assertions parseTokLeftPost parseTokRightPost Post follow

bound :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
bound follow recSet = assertions parseTokLeftBound parseTokRightBound Bound follow

assertion :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
assertion follow recSet = assertions parseTokLeftA parseTokRightA Assertion follow

invariant :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
invariant follow recSet = assertions parseTokLeftInv parseTokRightInv Invariant follow


listArgProc :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe [(T.Text, Type)])
listArgProc id follow recSet =
    do lookAhead follow
       return $ return []
       <|> do lookAhead parseEOF
              return Nothing
       <|> do ar <- arg id (follow <|> parseComma) (recSet <|> parseComma)
              rl <- listArgProcAux id follow recSet
              return (AP.liftA2 (:) ar rl)


listArgProcAux :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe [(T.Text, Type)])
listArgProcAux id follow recSet =
    do lookAhead follow
       return $ return []
       <|> do lookAhead parseEOF
              return Nothing
       <|> try (
             do parseComma
                ar <- arg id (follow <|> parseComma) (recSet <|> parseComma)
                rl <- listArgProcAux id follow recSet
                return(AP.liftA2 (:) ar rl)
               )
               <|> do genNewError follow PE.Comma
                      return Nothing


argType :: MyParser Token -> MyParser Token -> MyParser (Maybe TypeArg)
argType follow recSet =
    do lookAhead (parseIn <|> parseOut <|> parseInOut <|> parseRef)
       do parseIn
          return (return (In))
          <|> do parseOut
                 return (return (Out))
          <|> do parseInOut
                 return (return InOut)
          <|> do parseRef
                 return (return Ref)
    <|> do genNewError follow TokenArg
           return Nothing


arg :: T.Text -> MyParser Token -> MyParser Token -> MyParser (Maybe (T.Text, Type))
arg pid follow recSet =
    do at <- argType parseTokID (recSet <|> parseTokID)
       try (
         do id <- parseID
            try (
              do parseColon
                 t <- myType follow recSet
                 pos <- getPosition
                 addArgProcParser id pid t (toLocation pos) at
                 return $ return (id, t)
                )
                <|> do genNewError follow PE.Colon
                       return Nothing
           )
           <|> do genNewError follow PE.IDError
                  return Nothing

functionBody :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
functionBody follow recSet =
    do pos <- getPosition
       do parseBegin
          cif <- (conditional CExpression parseEnd parseEnd) <|> (expr parseEnd parseEnd)
          do parseEnd
             return cif
             <|> do genNewError follow PE.LexEnd
                    return Nothing
          <|> do genNewError follow PE.Begin
                 return Nothing


actionsList :: MyParser Token -> MyParser Token -> MyParser (Maybe [AST(Type)])
actionsList follow recSet =
  do lookAhead follow
     genNewEmptyError
     return Nothing
     <|> do ac <- action (follow <|> parseSemicolon) (recSet <|> parseSemicolon)
            rl <- actionsListAux follow recSet
            return $ AP.liftA2 (:) ac rl

actionsListAux :: MyParser Token -> MyParser Token -> MyParser (Maybe [AST(Type)])
actionsListAux follow recSet =
  do parseSemicolon
     ac <- action (follow <|> parseSemicolon) (recSet <|> parseSemicolon)
     rl <- actionsListAux follow recSet
     return (AP.liftA2 (:) ac rl)
     <|> do return $ return []

action :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
action follow recSet =
    do pos <- getPosition
       do  lookAhead followAction
           actionAux follow recSet
           <|> do lookAhead parseTokLeftA
                  as  <- assertion followAction (followAction <|> recSet)
                  do lookAhead followAction
                     res <- actionAux follow recSet
                     return $ AP.liftA3 (GuardAction (toLocation pos)) as res (return GEmpty)
                     <|> do genNewError follow Action
                            return Nothing
                  <|> do genNewError follow Action
                         return Nothing
           <|> do genNewError follow Action
                  return Nothing

actionAux :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
actionAux follow recSet =
        skip follow recSet
    <|> conditional CAction follow recSet
    <|> abort follow recSet
    <|> write follow recSet
    <|> writeln follow recSet
    <|> functionCallOrAssign follow recSet
    <|> random follow recSet
    <|> block follow recSet
    <|> repetition follow recSet


followAction ::  MyParser Token
followAction = (parseTokID <|> parseIf <|> parseAbort <|> parseSkip <|>
                  parseTokOpenBlock <|> parseWrite <|> parseWriteln <|> parseTokLeftInv <|> parseRandom)


block :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
block follow recSet =
    do pos <- getPosition
       parseTokOpenBlock
       newScopeParser
       dl  <- decList followAction (recSet <|> followAction)
       la  <- actionsList (parseTokCloseBlock) (parseTokCloseBlock <|> recSet)
       st  <- getActualScope
       exitScopeParser
       do parseTokCloseBlock
          return $ (AP.liftA2 (Block (toLocation pos) st) dl la) AP.<*> (return GEmpty)
          <|> do genNewError follow TokenCB
                 return Nothing


random :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
random follow recSet =
    do pos <- getPosition
       parseRandom
       do parseLeftParent
          do id  <- parseID
             do parseRightParent
                cont <- lookUpSymbol id
                let t = symbolType $ fromJust $ cont
                return $ return $ Ran id t (toLocation pos) GEmpty
                <|> do genNewError follow TokenRP
                       return Nothing
             <|> do genNewError follow IDError
                    return Nothing
          <|> do genNewError follow TokenLP
                 return Nothing


guardsList :: CasesConditional -> MyParser Token -> MyParser Token -> MyParser (Maybe [AST(Type)])
guardsList casec follow recSet =
    do g  <- guard casec (parseSepGuards <|> follow) (parseSepGuards <|> recSet)
       gl <- guardsListAux casec follow recSet
       return $ AP.liftA2 (:) g gl


guardsListAux :: CasesConditional -> MyParser Token -> MyParser Token -> MyParser (Maybe [AST(Type)])
guardsListAux casec follow recSet =
  do parseSepGuards
     g  <- guard casec (parseSepGuards <|> follow) (recSet <|> parseSepGuards)
     rl <- guardsListAux casec follow recSet
     return $ AP.liftA2 (:) g rl
     <|> do return $ return []


guard :: CasesConditional -> MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
guard CAction follow recSet     =
    do pos <- getPosition
       e <- expr (parseArrow) (recSet <|> parseArrow)
       parseArrow
       a <- action follow recSet
       return (AP.liftA2  (\f -> f (toLocation pos)) (AP.liftA2 Guard e a) (return (GEmpty)))

guard CExpression follow recSet =
    do pos <- getPosition
       e <- expr (parseArrow) (recSet <|> parseArrow)
       parseArrow
       do lookAhead parseIf
          a <-(conditional CExpression follow recSet)
          return (AP.liftA2 (\f -> f (toLocation pos)) (AP.liftA2 GuardExp e a) (return (GEmpty)))
          <|> do a <- expr follow recSet
                 return (AP.liftA2 (\f -> f (toLocation pos)) (AP.liftA2 GuardExp e a) (return (GEmpty)))


functionCallOrAssign ::  MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
functionCallOrAssign follow recSet =
    do pos <- getPosition
       id <- parseID
       do parseLeftParent
          lexp  <- listExp (follow <|> parseRightParent) (recSet <|> parseRightParent)
          do parseRightParent
             sb <- getActualScope
             return $ (fmap (ProcCall id sb (toLocation pos)) lexp) AP.<*> (return GEmpty)
             <|> do genNewError follow TokenRP
                    return Nothing
          <|> do bl <- bracketsList (parseComma <|> parseAssign) (parseComma <|> parseAssign <|> recSet)
                 rl <- idAssignListAux parseAssign (recSet <|> parseAssign)
                 t <- lookUpConsParser id
                 parseAssign
                 do le <- listExp follow recSet
                    case bl of
                      Nothing  -> return Nothing
                      Just bl' ->
                        case bl' of
                          [] ->
                            do let idast = fmap (ID (toLocation pos) id) t
                               return $ M.liftM4 LAssign (AP.liftA2 (:) idast rl) le (return (toLocation pos)) (return GEmpty)
                          otherwise ->
                            do let idast = (fmap (ArrCall (toLocation pos) id) bl) AP.<*>  t
                               return $ M.liftM4 LAssign (AP.liftA2 (:) idast rl) le (return (toLocation pos)) (return GEmpty)
                 <|> do genNewError follow TokenAs
                        return Nothing

idAssignListAux :: MyParser Token -> MyParser Token -> MyParser (Maybe ([AST Type]))
idAssignListAux follow recSet =
  do parseComma
     pos <- getPosition
     do ac <- parseID
        t  <- lookUpConsParser ac
        bl <- bracketsList (parseComma <|> parseAssign)
                (parseComma <|> parseAssign <|> recSet)
        rl <- idAssignListAux follow recSet
        case bl of
          Nothing  -> return Nothing
          Just bl' ->
            case bl' of
              [] ->
                do let ast = fmap (ID (toLocation pos) ac) t
                   return $ AP.liftA2 (:) ast rl
              otherwise ->
                do let ast = (fmap (ArrCall (toLocation pos) ac) bl) AP.<*>  t
                   return $ AP.liftA2 (:) ast rl
        <|> do genNewError follow IDError
               return Nothing
     <|> do return $ return []

write :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
write follow recSet =
    do pos <- getPosition
       parseWrite
       do parseLeftParent
          e   <- expr parseRightParent (recSet <|> parseRightParent)
          do parseRightParent
             return $ ((fmap (Write False) e) AP.<*> (return (toLocation pos)) AP.<*> (return GEmpty))
             <|> do genNewError follow TokenRP
                    return Nothing
          <|> do genNewError follow TokenLP
                 return Nothing


writeln ::  MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
writeln follow recSet =
    do pos <- getPosition
       parseWriteln
       do parseLeftParent
          e <- expr parseRightParent (recSet <|> parseRightParent)
          do parseRightParent
             return $ (fmap (Write True) e) AP.<*> (return (toLocation pos)) AP.<*> (return GEmpty)
             <|> do genNewError follow TokenRP
                    return Nothing
          <|> do genNewError follow TokenLP
                 return Nothing


abort ::  MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
abort folow recSet =
    do pos <- getPosition
       parseAbort
       return $ return $ Abort (toLocation pos) GEmpty


conditional :: CasesConditional -> MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
conditional casec follow recSet =
    do pos <- getPosition
       parseIf
       gl <- guardsList casec parseFi (recSet <|> parseFi)
       do parseFi
          return $ (fmap (Cond) gl) AP.<*> (return (toLocation pos)) AP.<*> (return GEmpty)
          <|> do genNewError follow TokenFI
                 return Nothing

repetition :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST(Type)) )
repetition follow recSet =
    do pos <- getPosition
       inv <- invariant (parseTokLeftBound) (recSet <|> parseTokLeftBound)
       bou <- bound (parseDo) (parseDo <|> recSet)
       do parseDo
          gl <- guardsList CAction parseOd (recSet <|> parseOd)
          do parseOd
             return((fmap (Rept) gl) AP.<*> inv AP.<*> bou AP.<*> (return (toLocation pos)) AP.<*> (return GEmpty))
             <|> do genNewError follow TokenOD
                    return Nothing
          <|> do genNewError follow TokEOFO
                 return Nothing

skip :: MyParser Token -> MyParser Token -> MyParser (Maybe (AST Type))
skip follow recSet =
    do  pos <- getPosition
        parseSkip
        return $ return $ Skip (toLocation pos) GEmpty
