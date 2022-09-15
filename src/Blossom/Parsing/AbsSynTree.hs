module Blossom.Parsing.AbsSynTree (
    ModuleAST(..),
    Import(..),
    TopLevelExpr(..),
    Function(..),
    Param(..),
    Expr(..),
    Data(..),
    Constructor(..),
    mkLambda,
) where

import qualified LLVM.AST as LLVM

import Blossom.Typing.Type


data ModuleAST = ModuleAST {
    moduleImports :: [Import],
    moduleTopExprs :: [TopLevelExpr]
    }

newtype Import = Import LLVM.Name

data TopLevelExpr
    = FuncDef Function
    | DataDef Data

data Function = Function {
    funcName :: Maybe LLVM.Name,
    funcParams :: [Param],
    funcBody :: Expr
    }

data Param = Param {
    paramName :: Maybe LLVM.Name,
    paramType :: Type
    }

data Expr
    = VarExpr LLVM.Name
    | FuncApp Expr Expr
    | Lambda Function
    | IfElse Expr Expr Expr

data Data = Data {
    dataName :: LLVM.Name,
    dataCtors :: [Constructor]
    }

data Constructor = Constructor {
    ctorName :: LLVM.Name,
    ctorTypes :: [LLVM.Name]
    }


mkLambda :: [Param] -> Expr -> Expr
mkLambda params = Lambda . Function Nothing params
