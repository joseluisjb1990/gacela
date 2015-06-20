module Lexer where

import Control.Monad.Identity (Identity)
import qualified Control.Applicative as AP
import qualified Data.Text as T
import Text.Parsec.Error
import Text.Parsec
import Token
import Type

tryString s = 
    try $ do s' <- string s 
             notFollowedBy $ alphaNum <|> char '_' <|> char '-' <|> char '?'
             return s'

tryStringOp = try . string

pPlus         = oneOf "+\43"
pMinus        = oneOf "-\45"
pStar         = oneOf "*\215"
pSlash        = oneOf "/\247"
pComma        = oneOf ","
pLeftParent   = oneOf "("
pRightParent  = oneOf ")"
pLeftBracket  = oneOf "["
pRightBracket = oneOf "]"
pVerticalBar  = oneOf "|"
pSemicolon    = oneOf ";"
pColon        = oneOf ":" 
pLeftBrace    = oneOf "{"
pRightBrace   = oneOf "}"
pLess         = oneOf "<\60"
pGreater      = oneOf ">\62"
pEqual        = oneOf "=\61"
pNot          = oneOf "!\33"
pAccent       = oneOf "^\94"
pPipe         = tryStringOp "|"
pOpenBlock    = tryStringOp "|["
pCloseBlock   = tryStringOp "]|"
pSepGuards    = tryStringOp "[]"
pLogicalAnd   = tryStringOp "/\\" <|> tryString "\8743" 
pLogicalOr    = tryStringOp "\\/" <|> tryString "\8744"
pNotEqual     = tryStringOp "!="  <|> tryString "\8800"
pLessEqual    = tryStringOp "<="  <|> tryString "\8804"
pGreaterEqual = tryStringOp ">="  <|> tryString "\8805"
pImplies      = tryStringOp "==>" <|> tryString "\8658"
pConsequent   = tryStringOp "<==" <|> tryString "\8656"
pEquiv        = tryStringOp "=="  <|> tryString "\8801"
pNotEqiv      = tryStringOp "!==" <|> tryString "\8802"
pAsig         = tryStringOp ":="  <|> tryString "\58\61" 
pArrow        = tryStringOp "->"  <|> tryString "\8594"
pLeftPercent  = tryStringOp "(%"  
pRightPercent = tryStringOp "%)"  
pLeftPre      = tryStringOp "{pre"
pRightPre     = tryStringOp "pre}"
pLeftPost     = tryStringOp "{post"
pRightPost    = tryStringOp "post}"
pLeftBound    = tryStringOp "{bound"
pRightBound   = tryStringOp "bound}"
pLeftA        = tryStringOp "{a"
pRightA       = tryStringOp "a}"
pLeftInv      = tryStringOp "{inv"
pRightInv     = tryStringOp "inv}"
pPre          = tryString "pre"
pPost         = tryString "post"
pBound        = tryString "bound"
pFunc         = tryString "func"
pProc         = tryString "proc"
pIn           = tryString "in"
pOut          = tryString "out"
pInOut        = tryString "inout"
pWith         = tryString "with"
pMod          = tryString "mod"
pMax          = tryString "max"
pMin          = tryString "min"
pForall       = tryString "forall"   <|> tryString "\8704" 
pExist        = tryString "exist"    <|> tryString "\8707" 
pNotExist     = tryString "notExist" <|> tryString "\8708"
pSigma        = tryString "sigma"    <|> tryString "\8721" 
pPi           = tryString "pi"       <|> tryString "\960"
pUnion        = tryString "union"    <|> tryString "\8746"
pIf           = tryString "if"
pFi           = tryString "fi"
pInv          = tryString "inv"
pDo           = tryString "do"
pOd           = tryString "od"
pGcd          = tryString "gcd"
pAbs          = tryString "abs"
pSqrt         = tryString "sqrt"     <|> tryString "\8730" 
pLength       = tryString "length"
pVar          = tryString "var"
pConst        = tryString "const"
pAbort        = tryString "abort"
pRandom       = tryString "random"
pSkip         = tryString "skip"
pWrite        = tryString "write"
pWriteln      = tryString "writeln"
pRead         = tryString "read"
pProgram      = tryString "program"  
pToInt        = tryString "toInt"
pToDouble     = tryString "toDouble"
pToChar       = tryString "toChar"
pToString     = tryString "toString"
pType         = (tryString "boolean" >> return MyBool)
            <|> (tryString "int"     >> return MyInt)
            <|> (tryString "double"  >> return MyFloat)
            <|> (tryString "char"    >> return MyChar)
            <|> (tryString "string"  >> return MyString)
pArray        = tryString "array"
pBool         = tryString "true"     <|> tryString "false"
pMIN_INT      = tryString "MIN_INT"
pMIN_DOUBLE   = tryString "MIN_DOUBLE"
pMAX_INT      = tryString "MAX_INT"
pMAX_DOUBLE   = tryString "MAX_DOUBLE"
pOf           = tryString "of"
pComment      = optional(do { tryString "//"; manyTill anyChar (lookAhead (newline)); spaces })



lexer :: Parsec T.Text () ([TokenPos])
lexer = do spaces
           pComment
           pos <- getPosition
           do  (eof >> spaces >> return ([(TokEnd, pos)]))
               <|> (do tok <- (   (pPlus         >> spaces >> return (TokPlus))
                              <|> (pArrow        >> spaces >> return (TokArrow))
                              <|> (pLogicalAnd   >> spaces >> return (TokLogicalAnd))
                              <|> (pLeftPre      >> spaces >> return (TokLeftPre))
                              <|> (pRightPre     >> spaces >> return (TokRightPre))
                              <|> (pLeftPost     >> spaces >> return (TokLeftPost))
                              <|> (pRightPost    >> spaces >> return (TokRightPost))
                              <|> (pLeftBound    >> spaces >> return (TokLeftBound))
                              <|> (pRightBound   >> spaces >> return (TokRightBound))
                              <|> (pType         AP.<* spaces >>= return . TokType)
                              <|> (pLeftA        >> spaces >> return (TokLeftA))
                              <|> (pRightA       >> spaces >> return (TokRightA))
                              <|> (pLeftInv      >> spaces >> return (TokLeftInv))
                              <|> (pRightInv     >> spaces >> return (TokRightInv))
                              <|> (pMinus        >> spaces >> return (TokMinus))
                              <|> (pStar         >> spaces >> return (TokStar))
                              <|> (pSlash        >> spaces >> return (TokSlash))
                              <|> (pComma        >> spaces >> return (TokComma))
                              <|> (pLeftPercent  >> spaces >> return (TokLeftPercent))
                              <|> (pRightPercent >> spaces >> return (TokRightPercent))
                              <|> (pLeftParent   >> spaces >> return (TokLeftParent))
                              <|> (pRightParent  >> spaces >> return (TokRightParent))
                              <|> (pAccent       >> spaces >> return (TokAccent))
                              <|> (pLogicalOr    >> spaces >> return (TokLogicalOr))
                              <|> (pNotEqual     >> spaces >> return (TokNotEqual))
                              <|> (pImplies      >> spaces >> return (TokImplies))
                              <|> (pConsequent   >> spaces >> return (TokConsequent))
                              <|> (pLessEqual    >> spaces >> return (TokLessEqual))
                              <|> (pGreaterEqual >> spaces >> return (TokGreaterEqual))
                              <|> (pEquiv        >> spaces >> return (TokEquiv))
                              <|> (pArray        >> spaces >> return (TokArray))
                              <|> (pNotEqiv      >> spaces >> return (TokNotEqiv))
                              <|> (pAsig         >> spaces >> return (TokAsig))
                              <|> (pLess         >> spaces >> return (TokLess))
                              <|> (pGreater      >> spaces >> return (TokGreater))
                              <|> (pEqual        >> spaces >> return (TokEqual))
                              <|> (pNot          >> spaces >> return (TokNot))
                              <|> (pProgram      >> spaces >> return (TokProgram))
                              <|> (pOpenBlock    >> spaces >> return (TokOpenBlock))
                              <|> (pCloseBlock   >> spaces >> return (TokCloseBlock))
                              <|> (pPipe         >> spaces >> return (TokPipe))
                              <|> (pSepGuards    >> spaces >> return (TokSepGuards))
                              <|> (pLeftBracket  >> spaces >> return (TokLeftBracket))
                              <|> (pRightBracket >> spaces >> return (TokRightBracket))
                              <|> (pVerticalBar  >> spaces >> return (TokVerticalBar))
                              <|> (pSemicolon    >> spaces >> return (TokSemicolon))
                              <|> (pColon        >> spaces >> return (TokColon))
                              <|> (pLeftBrace    >> spaces >> return (TokLeftBrace))
                              <|> (pRightBrace   >> spaces >> return (TokRightBrace))
                              <|> (pPre          >> spaces >> return (TokPre))
                              <|> (pPost         >> spaces >> return (TokPost))
                              <|> (pBound        >> spaces >> return (TokBound))
                              <|> (pFunc         >> spaces >> return (TokFunc))
                              <|> (pProc         >> spaces >> return (TokProc))
                              <|> (pInOut        >> spaces >> return (TokInOut))    
                              <|> (pOut          >> spaces >> return (TokOut))
                              <|> (pWith         >> spaces >> return (TokWith))
                              <|> (pMod          >> spaces >> return (TokMod))
                              <|> (pMax          >> spaces >> return (TokMax))
                              <|> (pMin          >> spaces >> return (TokMin))
                              <|> (pForall       >> spaces >> return (TokForall))
                              <|> (pExist        >> spaces >> return (TokExist))
                              <|> (pNotExist     >> spaces >> return (TokNotExist))
                              <|> (pSigma        >> spaces >> return (TokSigma))
                              <|> (pPi           >> spaces >> return (TokPi))
                              <|> (pUnion        >> spaces >> return (TokUnion))
                              <|> (pIf           >> spaces >> return (TokIf))
                              <|> (pFi           >> spaces >> return (TokFi))
                              <|> (pInv          >> spaces >> return (TokInv))
                              <|> (pDo           >> spaces >> return (TokDo))  
                              <|> (pOd           >> spaces >> return (TokOd))
                              <|> (pGcd          >> spaces >> return (TokGcd))
                              <|> (pAbs          >> spaces >> return (TokAbs))
                              <|> (pSqrt         >> spaces >> return (TokSqrt))
                              <|> (pLength       >> spaces >> return (TokLength))
                              <|> (pVar          >> spaces >> return (TokVar))
                              <|> (pConst        >> spaces >> return (TokConst))
                              <|> (pAbort        >> spaces >> return (TokAbort))
                              <|> (pRandom       >> spaces >> return (TokRandom))
                              <|> (pSkip         >> spaces >> return (TokSkip))
                              <|> (pWriteln      >> spaces >> return (TokWriteln))
                              <|> (pWrite        >> spaces >> return (TokWrite))
                              <|> (pRead         >> spaces >> return (TokRead))
                              <|> (pToInt        >> spaces >> return (TokToInt))
                              <|> (pToDouble     >> spaces >> return (TokToDouble))    
                              <|> (pToChar       >> spaces >> return (TokToChar))
                              <|> (pIn           >> spaces >> return (TokIn))
                              <|> (pMIN_INT      >> spaces >> return (TokMIN_INT))
                              <|> (pMIN_DOUBLE   >> spaces >> return (TokMIN_DOUBLE))
                              <|> (pMAX_INT      >> spaces >> return (TokMAX_INT))
                              <|> (pMAX_DOUBLE   >> spaces >> return (TokMAX_DOUBLE))
                              <|> (pOf           >> spaces >> return (TokOf))
                              <|> (pToString     >> spaces >> return (TokToString))
                              <|> (try (do s <- pBool
                                           spaces
                                           case s of
                                            { "true"  -> return $ TokBool True
                                            ; "false" -> return $ TokBool False
                                            }
                                        )
                                  ) 
                              <|> ((char '"')    AP.*> manyTill anyChar (char '"') AP.<* spaces >>= return . TokString)
                              <|> (do char '\''
                                      c <- anyChar
                                      char '\''
                                      spaces
                                      return (TokChar c)
                                  )
                              <|> (try( do n1 <- many1 digit
                                           char '.'
                                           n2 <- many1 digit
                                           return (TokFlotante (read (n1 ++ "." ++ n2))))
                                  )                             
                              <|> ((many1 digit)  AP.<* spaces >>= return . (TokInteger . read))
                              <|> (try (do l <- letter
                                           r <- many (alphaNum <|> char '_' <|> char '-' <|> char '?')
                                           spaces
                                           return $ TokId (T.cons l (T.pack r)) 
                                       )
                                  )
                              )
                       fmap ((tok, pos) :) lexer)
