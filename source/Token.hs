module Token where

import Text.Parsec
import Text.Parsec.Error
import Control.Monad.Identity (Identity)
import qualified Control.Applicative as AP
import qualified Data.Text as T


data Type = MyInt | MyFloat | MyBool | MyChar | MyString
  deriving (Show, Read, Eq) 
data TypeBool = MyTrue | MyFalse
  deriving (Show, Read, Eq) 

data Token =   TokPlus
             | TokMinus 
             | TokStar 
             | TokSlash 
             | TokSepGuards 
             | TokEnd 
             | TokComma 
             | TokLeftParent 
             | TokRightParent
             | TokLeftPercent
             | TokRightPercent
             | TokAccent
             | TokLogicalAnd
             | TokLogicalOr
             | TokNotEqual
             | TokLessEqual
             | TokGreaterEqual
             | TokImplies
             | TokConsequent
             | TokEquiv
             | TokNotEqiv
             | TokAsig
             | TokLess
             | TokGreater
             | TokEqual
             | TokNot 
             | TokProgram  
             | TokOpenBlock
             | TokCloseBlock
             | TokLeftBracket
             | TokRightBracket
             | TokVerticalBar
             | TokSemicolon
             | TokColon
             | TokLeftBrace
             | TokRightBrace
             | TokArrow
             | TokLeftPre
             | TokRightPre
             | TokLeftPost
             | TokRightPost
             | TokLeftBound
             | TokRightBound
             | TokLeftA
             | TokRightA
             | TokLeftInv
             | TokRightInv  
             | TokPre        
             | TokPost      
             | TokBound 
             | TokFunc      
             | TokProc     
             | TokIn      
             | TokOut 
             | TokInOut       
             | TokWith             
             | TokMod    
             | TokMax         
             | TokMin      
             | TokForall      
             | TokExist    
             | TokNotExist   
             | TokSigma      
             | TokPi          
             | TokUnion      
             | TokIf         
             | TokFi        
             | TokInv       
             | TokDo         
             | TokOd         
             | TokGcd        
             | TokAbs       
             | TokSqrt      
             | TokLength     
             | TokVar      
             | TokConst     
             | TokAbort       
             | TokRandom      
             | TokSkip        
             | TokWrite    
             | TokWriteln
             | TokRead     
             | TokToInt      
             | TokToDouble   
             | TokToChar      
             | TokToString                
             | TokMIN_INT     
             | TokMIN_DOUBLE 
             | TokMAX_INT   
             | TokMAX_DOUBLE 
             | TokOf
             | TokArray
             | TokChar    { rchar :: T.Text   }
             | TokBool    { nBool :: TypeBool }      
             | TokType    { nType :: T.Text   }
             | TokId      { text  :: T.Text   }
             | TokString  { st    :: T.Text   }
             | TokInteger { num   :: T.Text   }
             | TokFlotante T.Text T.Text
             | TokError T.Text
      deriving (Read, Eq)

instance Show Token where
  show TokPlus          = "suma"
  show TokMinus         = "resta"
  show TokStar          = "multiplicación"   
  show TokSlash         = "división"        
  show TokEnd           = "fin de archivo"
  show TokComma         = "coma"
  show TokLeftParent    = "paréntesis izquierdo"
  show TokRightParent   = "paréntesis derecho"
  show TokLeftPercent   = "cuantificador de apertura"
  show TokRightPercent  = "cuantificador de cierre"
  show TokAccent        = "potencia"
  show TokLogicalAnd    = "y lógico"
  show TokLogicalOr     = "o lógico"
  show TokNotEqual      = "inequivalencia"
  show TokLessEqual     = "menor o igual que"
  show TokGreaterEqual  = "mayor o igual que"
  show TokImplies       = "implicación"
  show TokConsequent    = "consecuencia"
  show TokEquiv         = "equivalencia"
  show TokNotEqiv       = "no equivalencia"
  show TokAsig          = "asignación"
  show TokLess          = "menor que"
  show TokGreater       = "mayor que"
  show TokEqual         = "igual" 
  show TokNot           = "negacion"
  show TokProgram       = "programa"
  show TokLeftBracket   = "corchete de apertura"
  show TokRightBracket  = "corchete de cierre"
  show TokVerticalBar   = "barra" 
  show TokSemicolon     = "punto y coma"
  show TokColon         = "punto"
  show TokLeftBrace     = "llave de apertura"
  show TokRightBrace    = "llave de cierre"
  show TokArrow         = "flecha de tipo de retorno"
  show TokLeftPre       = "precondición de apertura"
  show TokRightPre      = "precondición de cierre"
  show TokLeftPost      = "postcondición de apertura"
  show TokRightPost     = "postcondición de cierre"
  show TokLeftBound     = "cuota de apertura"
  show TokRightBound    = "cuota de cierre"
  show TokLeftA         = "absorción de apertura"
  show TokRightA        = "absorción de cierre"
  show TokLeftInv       = "invariante de apertura"
  show TokRightInv      = "invariante de cierre"
  show TokPre           = "precondición"
  show TokPost          = "postcondición"
  show TokBound         = "cuota"
  show TokFunc          = "función"
  show TokProc          = "procedimiento"
  show TokIn            = "entrada"
  show TokOut           = "salida"
  show TokInOut         = "entrada y salida"
  show TokWith          = "token with"   
  show TokMod           = "modulo"
  show TokMax           = "maximo"
  show TokMin           = "minimo"
  show TokForall        = "para todo"
  show TokExist         = "existencial"
  show TokNotExist      = "no existencial"
  show TokSigma         = "sumatoria"
  show TokPi            = "número pi"
  show TokUnion         = "union"
  show TokIf            = "if de apertura"
  show TokFi            = "if de cierre"
  show TokInv           = "invariante"
  show TokDo            = "do de apertura"
  show TokOd            = "do de cierre"
  show TokGcd           = "máximo común divisor"
  show TokAbs           = "valor absoluto"
  show TokSqrt          = "raíz cuadrada"
  show TokLength        = "longitud"
  show TokVar           = "variable"
  show TokConst         = "constante"
  show TokAbort         = "abortar"
  show TokRandom        = "random"
  show TokSkip          = "saltar"
  show TokWrite         = "escribir"
  show TokWriteln       = "escribir con salto de línea"
  show TokRead          = "leer"
  show TokToInt         = "conversión a entero"
  show TokToDouble      = "conversión a flotante"
  show TokToChar        = "conversión a caracter"
  show TokToString      = "conversión a cadena de caracteres"          
  show TokMIN_INT       = "entero mínimo"
  show TokMIN_DOUBLE    = "flotante mínimo"
  show TokMAX_INT       = "entero máximo" 
  show TokMAX_DOUBLE    = "flotante máximo"
  show TokOf            = "token of"
  show (TokBool b)      = "booleano : " ++ show b
  show (TokType b)      = "tipo: " ++ show b
  show (TokInteger b)   = "numero : " ++ show b
  show (TokId      b)   = "ID : " ++ show b
  show (TokString  e)   = "cadena de caracteres " ++ show e
  show (TokError   e)   = "cadena no reconocida " ++ show e
  show (TokFlotante n1 n2) = "Numero flotante : " ++ show n1 ++ "." ++ show n2 
  show (TokChar c)      = "caracter " ++ show c  
  show (TokOpenBlock)   = "simbolo de apertura de bloque"
  show (TokCloseBlock)  = "simbolo de cierre de bloque"
  show TokSepGuards     = "simbolo separador de guardias"
  show TokArray         = "tipo arreglo de"

type TokenPos = (Token, SourcePos)

makeTokenParser x = token showTok posTok testTok
                    where
                      showTok (t, pos) = show t
                      posTok  (t, pos) = pos
                      testTok (t, pos) = if x == t then Just (t) else Nothing

verify :: Token -> Parsec ([TokenPos]) () (Token)
verify token = makeTokenParser token

parsePlus         = verify TokPlus
parseMinus        = verify TokMinus
parseSlash        = verify TokSlash
parseStar         = verify TokStar
parseComma        = verify TokComma
parseLeftParent   = verify TokLeftParent
parseRightParent  = verify TokRightParent
parseEnd          = verify TokEnd
parseMaxInt       = verify TokMAX_INT
parseMinInt       = verify TokMIN_INT
parseMaxDouble    = verify TokMAX_DOUBLE
parseMinDouble    = verify TokMIN_DOUBLE
parseProgram      = verify TokProgram
parseLBracket     = verify TokLeftBracket
parseRBracket     = verify TokRightBracket
parseToInt        = verify TokToInt
parseToDouble     = verify TokToDouble
parseToChar       = verify TokToChar
parseToString     = verify TokToString
parseLeftBracket  = verify TokLeftBracket
parseRightBracket = verify TokRightBracket
parseTokAbs       = verify TokAbs
parseTokSqrt      = verify TokSqrt
parseTokAccent    = verify TokAccent
parseAnd          = verify TokLogicalAnd
parseOr           = verify TokLogicalOr
parseNotEqual     = verify TokNotEqual
parseEqual        = verify TokEquiv
parseSkip         = verify TokSkip        
parseIf           = verify TokIf
parseFi           = verify TokFi
parseAbort        = verify TokAbort
parseWrite        = verify TokWrite
parseSemicolon    = verify TokSemicolon
parseArrow        = verify TokArrow
parseSepGuards    = verify TokSepGuards
parseDo           = verify TokDo
parseOd           = verify TokOd
parseAssign       = verify TokAsig
parseRandom       = verify TokRandom
parseTokOpenBlock = verify TokOpenBlock
parseTokCloseBlock= verify TokCloseBlock
parseColon        = verify TokColon
parseVar          = verify TokVar
parseConst        = verify TokConst
parseFunc         = verify TokFunc
parseProc         = verify TokProc
parseIn           = verify TokIn
parseOut          = verify TokOut
parseInOut        = verify TokInOut
parseRead         = verify TokRead
parseWith         = verify TokWith
parseWriteln      = verify TokWriteln
parseOf           = verify TokOf 
parseTokArray     = verify TokArray

parseID :: Parsec ([TokenPos]) () (Token)
parseID = token showTok posTok testTok
          where
            showTok (t, pos) = show t
            posTok  (t, pos) = pos
            testTok (t, pos) = case t of
                                 { TokId id  -> Just (TokId id)
                                 ; otherwise -> Nothing
                                 }

parseBool :: Parsec ([TokenPos]) () (Token)
parseBool = token showTok posTok testTok
            where
              showTok (t, pos) = show t
              posTok  (t, pos) = pos
              testTok (t, pos) = case t of
                                  { TokBool b -> Just (TokBool b)
                                  ; otherwise -> Nothing
                                  }

parseType :: Parsec ([TokenPos]) () (Token)
parseType = token showTok posTok testTok
              where
                showTok (t, pos) = show t
                posTok  (t, pos) = pos
                testTok (t, pos) = case t of
                                    { TokType b -> Just (TokType b)
                                    ; otherwise -> Nothing
                                    }

parseChar :: Parsec ([TokenPos]) () (Token)
parseChar = token showTok posTok testTok
            where
              showTok (t, pos) = show t
              posTok  (t, pos) = pos
              testTok (t, pos) = case t of
                                  { TokChar b -> Just (TokChar b)
                                  ; otherwise -> Nothing
                                  }

parseString :: Parsec ([TokenPos]) () (Token)
parseString = token showTok posTok testTok
                where
                  showTok (t, pos) = show t
                  posTok  (t, pos) = pos
                  testTok (t, pos) = case t of
                                      { TokString b -> Just (TokString b)
                                      ; otherwise   -> Nothing
                                      }

parseAnyToken :: Parsec ([TokenPos]) () (Token)
parseAnyToken = token showTok posTok testTok
                where
                  showTok (t, pos) = show t
                  posTok  (t, pos) = pos
                  testTok (t, pos) = Just (t)

number :: Parsec ([TokenPos]) () (Token)
number = token showTok posTok testTok
          where
            showTok (t, pos) = show t
            posTok  (t, pos) = pos
            testTok (t, pos) = case t of
                                { TokInteger n -> Just (TokInteger n)
                                ; otherwise    -> Nothing
                                }
