module TypeChecking.Monad
    ( EDocM, TCM, runTCM
    , addFunctionCheck, addDataTypeCheck, addConstructorCheck
    , module TypeChecking.Monad.Warn
    , module TypeChecking.Monad.Scope
    , lift
    ) where

import Bound.Var
import Control.Monad
import Control.Monad.Trans(lift)

import TypeChecking.Monad.Warn
import TypeChecking.Monad.Scope
import Syntax.Term
import Syntax.Expr
import Syntax.ErrorDoc

type EDocM = WarnT [EMsg Term]
type TCM m = EDocM (ScopeT Term m)

runTCM :: Monad m => TCM m a -> m (Maybe a)
runTCM = liftM snd . runScopeT . runWarnT

multipleDeclaration :: Arg -> String -> EMsg f
multipleDeclaration arg var = emsgLC (argGetPos arg) ("Multiple declarations of " ++ show var) enull

addFunctionCheck :: Monad m => Arg -> Term String -> Term String -> TCM m ()
addFunctionCheck arg te ty = do
    let var = unArg arg
    mr <- lift (getEntry var Nothing)
    case mr of
        Just _  -> throwError [multipleDeclaration arg var]
        Nothing -> lift (addFunction var te ty)

addDataTypeCheck :: Monad m => Arg -> Term String -> TCM m ()
addDataTypeCheck arg ty = do
    let var = unArg arg
    mr <- lift (getEntry var Nothing)
    case mr of
        Just (FunctionE _ _) -> throwError [multipleDeclaration arg var]
        Just (DataTypeE _) -> throwError [multipleDeclaration arg var]
        _                   -> lift (addDataType var ty)

addConstructorCheck :: Monad m => Arg -> String -> Int -> Term (Var Int String) -> TCM m ()
addConstructorCheck arg dt i ty = do
    let var = unArg arg
    mr <- lift $ getEntry var (Just dt)
    case mr of
        Just (FunctionE _ _)    -> throwError [multipleDeclaration arg var]
        Just (ConstructorE _ _) -> throwError [multipleDeclaration arg var]
        _                      -> lift (addConstructor var dt i ty)
