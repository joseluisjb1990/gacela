module MyParseError where

import qualified Text.Parsec.Pos as P
import Location
import Token


data MyParseError = MyParseError   { loc       :: Location
                                   , waitedTok :: WaitedToken
                                   , actualTok :: Token
                                   }
                  | EmptyError     { loc       :: Location 
                                   }
                  | ArrayError     { waDim     :: Int
                                   , prDim     :: Int
                                   , loc       :: Location 
                                   }
                  | NonAsocError   { loc       :: Location 
                                   }
                  | ScopesError


data WaitedToken =  Operator
                  | Number
                  | TokenRP
                  | TokenRB
                  | Comma
                  | Final
                  | Program
                  | TokenOB
                  | TokenCB
                  | ProcOrFunc
                  | Colon
                  | IDError

instance Show WaitedToken where
  show Operator   = "operador"
  show Number     = "número"
  show TokenRP    = "paréntesis derecho"
  show Comma      = "coma"
  show Final      = "final de archivo"
  show TokenRB    = "corchete derecho"
  show TokenOB    = "apertura de bloque"
  show TokenCB    = "final de bloque"
  show Program    = "program"
  show ProcOrFunc = "procedimiento o función"
  show Colon      = "dos puntos"
  show IDError    = "identificador"


instance Show MyParseError where
  show (MyParseError loc wt at) = 
      errorL loc ++ ": Esperaba " ++ show wt ++ " en vez de " ++ show at ++ "."
  show (EmptyError   loc)       = 
      errorL loc ++ ": No se permiten expresiones vacías."
  show (NonAsocError loc)       = 
      errorL loc ++ ": Operador no asociativo."
  show (ArrayError   wt pr loc) = 
      errorL loc ++ ": Esperaba Arreglo de dimensión " ++ show wt ++ ", encontrado Arreglo de dimensión " ++ show pr ++ "."     
  show ScopesError              = 
      "Error en la tabla de símbolos: intento de salir de un alcance sin padre."
    

newEmptyError  pos          = 
    EmptyError   { loc = Location (P.sourceLine pos) (P.sourceColumn pos) (P.sourceName pos)                                 }
newParseError  msg (e, pos) = 
    MyParseError { loc = Location (P.sourceLine pos) (P.sourceColumn pos) (P.sourceName pos), 
                                                                waitedTok = msg, actualTok = e }
