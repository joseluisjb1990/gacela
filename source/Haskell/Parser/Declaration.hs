{-# LANGUAGE NamedFieldPuns #-}

{-|
Module      : Declarations
Description : Parseo y almacenamiento de las declaraciones
Copyright   : Graciela

Se encuentra todo lo referente al almacenamiento de las variables
en la tabla de simbolos, mientras se esta realizando el parser.
-}

module Parser.Declaration 
    ( declaration
    , dataTypeDeclaration
    , abstractDeclaration
    )
    where
-------------------------------------------------------------------------------
import           AST.Declaration           (Declaration (..))
import           AST.Expression            (Expression (..),
                                            Expression' (Value, NullPtr))
import           AST.Struct                (Struct(..))
import           Entry                     as E
import           Error
import           Location
import           Parser.Expression
import           Parser.Monad
-- import           Parser.Rhecovery
import           Parser.State
import           Parser.Type
import           SymbolTable
import           Token
import           AST.Type
--------------------------------------------------------------------------------
import           Control.Lens              (use, (%=))
import           Control.Monad             (foldM, forM_, unless, void, when,
                                            zipWithM_)
-- import           Control.Monad.Trans.State.Lazy
import           Control.Monad.Trans.Class (lift)
import           Data.Functor              (($>))
import           Data.Monoid               ((<>))
import           Data.Map                  as Map (lookup)
import           Data.Sequence             (Seq, (|>))
import qualified Data.Sequence             as Seq (empty, fromList, null, zip)
import           Data.Text                 (Text, unpack)
import           Debug.Trace
import           Prelude                   hiding (lookup)
import           Text.Megaparsec           (getPosition, notFollowedBy,
                                            optional, try, (<|>), lookAhead)
--------------------------------------------------------------------------------
type Constness = Bool
-- | Se encarga del parseo de las variables y su almacenamiento en
-- la tabla de simbolos.

-- Only regular types
declaration :: Parser (Maybe Declaration)
declaration = declaration' type' False

-- Accept polymorphic types
dataTypeDeclaration :: Parser (Maybe Declaration)
dataTypeDeclaration = declaration' type' True


-- Accept both, polymorphic and abstract types (set, function, ...)
abstractDeclaration :: Parser (Maybe Declaration)
abstractDeclaration = declaration' abstractType True

declaration' :: Parser Type -> Bool -> Parser (Maybe Declaration)
declaration' allowedTypes isStruct = do
  from <- getPosition

  isConst <- match TokConst $> True <|> match TokVar $> False
  ids <- identifierAndLoc `sepBy1` match TokComma
  mvals <- (if isConst then assignment' else assignment) 

  match TokColon
  t <- if isConst then type' else allowedTypes

  to <- getPosition
  let
    location = Location (from, to)

  if isConst && not (t =:= GOneOf [GBool, GChar, GInt, GFloat] )
    then do
      putError from . UnknownError $
        "Se intentó declarar constante de tipo `" <> show t <>
        "`, pero sólo se permiten constantes de tipos basicos."
      pure Nothing
    else case mvals of
      Nothing -> do
        -- Values were optional, and were not given
        forM_ ids $ \(id, loc) -> do
          redef <- redefinition (id, loc)
          unless redef  $ do
            let
              info = if isStruct
                then SelfVar t Nothing
                else Var t Nothing

              entry = Entry
                  { _entryName = id
                  , _loc       = loc
                  , _info      = info }
            symbolTable %= insertSymbol id entry
       
        pure . Just $ Declaration
          { declLoc  = location
          , declType = t
          , declIds  = fst <$> ids }

      Just Nothing  -> do
        pure Nothing
        -- Values were either mandatory or optional, and were given, but
        -- had errors. No more errors are given.

      Just (Just exprs) ->
        -- Values were either mandatory or optional, but were given
        -- anyways, without errors in any.
        if length ids == length exprs
          then do
            pairs <- foldM (checkType isConst t isStruct) Seq.empty $ Seq.zip ids exprs
            pure $ if null pairs
              then 
                Nothing
              else Just Initialization
                { declLoc   = location
                , declType  = t
                , declPairs = pairs }
          else do
            putError from . UnknownError $
              "The number of " <>
              (if isConst then "constants" else "variables") <>
              " do not match with the\n\tnumber of expressions to be assigned"
            pure Nothing


assignment :: Parser (Maybe (Maybe (Seq Expression)))
assignment = optional $ sequence <$>
  (match TokAssign *> (expression `sepBy` match TokComma))

assignment' :: Parser (Maybe (Maybe (Seq Expression)))
assignment' = Just . sequence <$>
  (match' TokAssign *> (expression `sepBy` match TokComma))


checkType :: Constness -> Type -> Bool
          -> Seq (Text, Expression)
          -> ((Text, Location), Expression)
          -> Parser (Seq (Text, Expression))
checkType True t _ pairs
  ((identifier, location), expr@Expression { expType, exp' }) = do
  

  let Location (from, _) = location
  redef <- redefinition (identifier,location)
      
  if expType =:= t
    then  if redef 
      then pure pairs
      else case exp' of
        Value v -> do
          let
            expr' = case exp' of
              NullPtr {} -> expr{expType = t}
              _ -> expr

            entry = Entry
              { _entryName  = identifier
              , _loc        = location
              , _info       = Const
                { _constType  = t
                , _constValue = v }}
          symbolTable %= insertSymbol identifier entry
          pure $ pairs |> (identifier, expr')
        _       -> do
          putError from . UnknownError $
            "Trying to assign a non constant expression to the \
            \constant `" <> unpack identifier <> "`."
          pure Seq.empty

    else do
      putError from . UnknownError $
        "Trying to assign an expression with type " <> show expType <>
        " to the constant `" <> unpack identifier <> "`, of type " <>
        show t <> "."
      pure Seq.empty

checkType False t isStruct pairs 
  ((identifier, location), expr@Expression { loc, expType, exp' }) =

  let Location (from, _) = location
  in if expType =:= t
    then do
      redef <- redefinition (identifier,location)
      if redef
        then pure pairs
        else do
          let
            info = if isStruct
              then SelfVar t
              else Var t 
            expr' = case exp' of
              NullPtr {} -> expr{expType = t}
              _ -> expr

            entry = Entry
              { _entryName  = identifier
              , _loc        = location
              , _info       = info (Just expr') }

          symbolTable %= insertSymbol identifier entry
          pure $ pairs |> (identifier, expr')

    else do
      putError from . UnknownError $
        "Trying to assign an expression with type " <> show expType <>
        " to the variable `" <> unpack identifier <> "`, of type " <>
        show t <> "."
      pure Seq.empty

redefinition :: (Text, Location) -> Parser Bool
redefinition (id, Location (from, _)) = do
  st <- use symbolTable
  let local = isLocal id st

  if local
    then do 
      putError from . UnknownError $
         "Redefinition of variable `" <> unpack id <> "`"
      pure True
    else do
      maybeStruct <- use currentStruct
      case maybeStruct of
        Just (GDataType _ (Just abstName) _, _, _) -> do
          adt <- getStruct abstName
          case adt of
            Just abst -> do 
              if isLocal id . structSt $ abst
                then do 
                  putError from . UnknownError $
                    "Redefinition of variable `" <> unpack id <> 
                    "`. Was defined in Abstract Type `" <> unpack abstName <> "`"
                  pure True
                else pure False
            _ -> pure False
        _ -> pure False
          
