{-# LANGUAGE FlexibleInstances #-}

module Syntax.PrettyPrinter
    ( ppTerm
    ) where

import Text.PrettyPrint
import Data.Bifoldable
import Data.Void

import Syntax
import qualified Syntax.ErrorDoc as E

instance E.Pretty1 (Term Syntax) where
    pretty1 t = ppTermCtx (freeVars t) t

freeVars :: Term Syntax a -> [String]
freeVars = biconcatMap (\t -> case t of
    Name s  -> [getStr s]
    _       -> []) (const [])

ppTerm :: Term Syntax Void -> Doc
ppTerm t = ppTermCtx (freeVars t) (vacuous t)

ppTermCtx :: [String] -> Term Syntax Doc -> Doc
ppTermCtx ctx (Var d ts) = d <+> ppList ctx ts
ppTermCtx ctx (Apply s ts) = ppSyntax ctx s ts
ppTermCtx _ _ = error "ppTermCtx"

ppSyntax :: [String] -> Syntax -> [Term Syntax Doc] -> Doc
ppSyntax ctx p@(Pi vs) [t1, t2] = (if null vs
    then ppTermPrec (prec p + 1) ctx t1
    else parens $ hsep (map text vs) <+> colon <+> ppTermCtx ctx t1) <+> arrow <+> ppBound (prec p) ctx vs t2
ppSyntax ctx l@(Lam vs) (t:ts) = bparens (not $ null ts) (text "\\" <> hsep (map text vs) <+> arrow <+> ppBound (prec l) ctx vs t) <+> ppList ctx ts
ppSyntax ctx t@PathImp [_,t2,t3] = ppTermPrec (prec t + 1) ctx t2 <+> equals <+> ppTermPrec (prec t + 1) ctx t3
ppSyntax ctx t@At (_:_:t3:t4:ts) = ppTermPrec (prec t) ctx t3 <+> text "@" <+> ppTermPrec (prec t + 1) ctx t4 <+> ppList ctx ts
ppSyntax ctx (Name n) ts = (case n of
    Ident s -> text s
    Operator s -> parens $ text s) <+> ppList ctx ts
ppSyntax _ _ _ = error "ppSyntax"

ppList :: [String] -> [Term Syntax Doc] -> Doc
ppList ctx ts = hsep $ map (ppTermPrec 10 ctx) ts

ppBound :: Int -> [String] -> [String] -> Term Syntax Doc -> Doc
ppBound p ctx (v:vs) (Lambda t) =
    let (ctx',v') = renameName2 v ctx (freeVars t)
    in ppBound p ctx' vs $ instantiate1 (capply $ Name $ Ident v') t
ppBound p ctx _ t = ppTermPrec p ctx t

ppTermPrec :: Int -> [String] -> Term Syntax Doc -> Doc
ppTermPrec p ctx t = bparens (p > precTerm t) (ppTermCtx ctx t)

bparens :: Bool -> Doc -> Doc
bparens True d = parens d
bparens False d = d

arrow :: Doc
arrow = text "->"

renameName :: String -> [String] -> ([String], String)
renameName var ctx = if var `Prelude.elem` ctx then renameName (var ++ "'") ctx else (var:ctx,var)

renameName2 :: String -> [String] -> [String] -> ([String], String)
renameName2 var ctx ctx' = if var `elem` ctx && var `elem` ctx'
    then renameName (var ++ "'") ctx'
    else (var:ctx,var)

prec :: Syntax -> Int
prec Name{}     = 10
prec At         = 8
prec PathImp{}  = 7
prec Pi{}       = 6
prec Lam{}      = 5

precTerm :: Term Syntax a -> Int
precTerm Var{} = 10
precTerm (Apply Name{} (_:_)) = 9
precTerm (Apply s _) = prec s
precTerm (Lambda t) = precTerm t
