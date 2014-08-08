module TypeChecking.Monad
    ( EDocM, TCM, runTCM
    , addFunctionCheck, addDataTypeCheck, addConstructorCheck
    , module TypeChecking.Monad.Warn
    , module TypeChecking.Monad.Scope
    , lift
    ) where

import Data.Void
import Control.Monad
import Control.Monad.Trans(lift)

import TypeChecking.Monad.Warn
import TypeChecking.Monad.Scope
import Syntax
import Semantics
import Semantics.Value
import Syntax.ErrorDoc

type EDocM = WarnT [EMsg (Term Syntax)]
type TCM m = EDocM (ScopeT m)

runTCM :: Monad m => TCM m a -> m (Maybe a)
runTCM = liftM snd . runScopeT . runWarnT

multipleDeclaration :: Posn -> Name -> EMsg f
multipleDeclaration pos var = emsgLC pos ("Multiple declarations of " ++ show (getStr var)) enull

addFunctionCheck :: Monad m => PName -> SEval -> Type Semantics Void -> TCM m ID
addFunctionCheck (pos, var) e ty = do
    mr <- lift (getEntry var Nothing)
    if null mr then lift (addFunction var e ty) else throwError [multipleDeclaration pos var]

addDataTypeCheck :: Monad m => PName -> Int -> Type Semantics Void -> TCM m ID
addDataTypeCheck (pos, var) n ty = do
    mf <- lift (getFunction var)
    md <- lift (getDataType var)
    if null mf && null md then lift (addDataType var n ty) else throwError [multipleDeclaration pos var]

addConstructorCheck :: Monad m => PName -> ID -> Int -> Int -> SEval -> Type Semantics Void -> TCM m ()
addConstructorCheck (pos, var) dt i n e ty = do
    mf <- lift (getFunction var)
    mc <- lift $ getConstructor var (Just dt)
    if null mf && null mc then lift (addConstructor var dt i n e ty) else warn [multipleDeclaration pos var]
