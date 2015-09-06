module Contents where

import Data.Text as T hiding (map)
import Location
import Type

data VarBehavour = Constant | Variable
      deriving (Eq)


instance Show VarBehavour where
  show Contents.Constant  = " es una Constante"
  show Variable           = " es una Variable"


data Value = I Integer | C Char | D Double | S String | B Bool
    deriving (Show, Eq)


data Contents s = Contents    { varBeh      :: VarBehavour, symbolLoc :: Location, symbolType :: Type, value :: Maybe Value, ini :: Bool }
                | ArgProcCont { procArgType :: TypeArg    , symbolLoc :: Location, symbolType :: Type                                    }
                | FunctionCon { symbolLoc :: Location, symbolType :: Type, nameArgs :: [T.Text], sTable :: s                             }
                | ProcCon     { symbolLoc :: Location, symbolType :: Type, nameArgs :: [T.Text], sTable :: s                             }
        deriving (Eq)


instance Show a => Show (Contents a) where
   show (Contents var loc t v i)  = show var  ++ ", Tipo: " ++ show t  ++ ", Declarada en: " ++ show loc ++ ", Valor: " ++ show v ++ ", Inicializada: " ++ show i
   show (ArgProcCont argT loc t)  = show argT ++ ", Tipo: " ++ show t  ++ ", Declarada en: " ++ show loc 
   show (FunctionCon loc t args _)   =              ", Tipo: " ++ show t  ++ ", Declarada en: " ++ show loc ++ ", Argumentos: " ++ show (map T.unpack args)
   show (ProcCon _ _ ln sb)       = show ln ++ show sb

   
isInitialized :: Contents a -> Bool
isInitialized (Contents _ _ _ _ True)  = True
isInitialized (ArgProcCont _ _ _)      = True
isInitialized (FunctionCon _ _ _ _   ) = True
isInitialized (ProcCon _ _ _ _   )     = True
isInitialized _                        = False


isRValue :: Contents a -> Bool
isRValue (Contents _ _ _ _ _    ) = True
isRValue (ArgProcCont In _ _    ) = True
isRValue (ArgProcCont InOut _ _ ) = True
isRValue (FunctionCon _ _ _ _   ) = True
isRValue (ProcCon _ _ _ _   )     = True
isRValue _                        = False


isLValue :: Contents a -> Bool
isLValue (Contents Variable _ _ _ _) = True
isLValue (ArgProcCont Out _ _)       = True
isLValue (ArgProcCont InOut _ _)     = True
isLValue _                           = False


isArg :: Contents a -> Bool
isArg (Contents _ _ _ _ _) = False
isArg _                    = True


initSymbolContent :: Contents a -> Contents a
initSymbolContent (Contents vb loc t v _) = Contents vb loc t v True
initSymbolContent c                       = c


getVarBeh :: Contents a -> Maybe VarBehavour
getVarBeh (Contents vb _ _ _ _) = Just vb
getVarBeh _                     = Nothing


getProcArgType :: Contents a -> Maybe TypeArg
getProcArgType (ArgProcCont pat _ _) = Just pat
getProcArgType _                     = Nothing
