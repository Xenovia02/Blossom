{
{-# OPTIONS_GHC -fno-prof-auto #-}
{-# OPTIONS_GHC -fprof-auto-exported #-}

module Blossom.Parsing.Parser (
    parseFile,
    parse,
) where

import Blossom.Common.Literal (Literal(..))
import Blossom.Common.Name (ModuleName, Ident)
import Blossom.Parsing.AbsSynTree (
    Case(..),
    Constructor(..),
    Expr(..),
    Import(..),
    ModuleAST(..),
    Params,
    Pattern(..),
    TopLevelExpr(..),
    Type(..),
    )
import Blossom.Parsing.Lexer (
    Alex,
    lexError,
    lexer,
    runLexer,
    )
import Blossom.Parsing.Token (Token(..))
import Data.ByteString.Lazy as BS (ByteString, toStrict, readFile)
import Prettyprinter (pretty, (<+>))
}


%name blossomParser Module
%error { parseError }
%lexer { lexer } { TokEnd }
%monad { Alex }
%expect 4

%tokentype { Token }
%token
    integer                 { TokInteger $$ }
    float                   { TokFloat $$ }
    char                    { TokChar $$ }
    string                  { TokString $$ }
    operator                { TokOperator $$ }
    small_id                { TokSmallId $$ }
    big_id                  { TokBigId $$ }
    "\\"                    { TokBackslash }
    ";"                     { TokSemi }
    ":"                     { TokColon }
    "->"                    { TokArrow }
    "="                     { TokEquals }
    "=>"                    { TokEqArrow }
    "("                     { TokLParen }
    ")"                     { TokRParen }
    "{"                     { TokLBrace }
    "}"                     { TokRBrace }
    import                  { TokImport }
    func                    { TokFunc }
    data                    { TokData }
    match                   { TokMatch }

-- PLEASE NOTE: If function application is not as expected,
-- please remove the following precedence declaration.
-- It did turn 12 s/r conflicts into reduces for FuncApp.
-- (commented out bc it messed things up. :/)
-- %nonassoc integer float string small_id big_id char "(" -- "->"

-- ghost precedence for function application
-- https://stackoverflow.com/questions/27630269
-- %nonassoc APP


%%


Module :: { ModuleAST }
    : ImportList TopLevel { ModuleAST $1 $2 }

ImportList :: { [Import] }
    : ImportList Import { ($2:$1) }
    | {- EMPTY -} { [] }

Import :: { Import }
    : import big_id ";" { Import $2 }

TopLevel :: { [TopLevelExpr] }
    : TopLevel TopLevelExpr { ($2:$1) }
    | {- EMPTY -} { [] }

TopLevelExpr :: { TopLevelExpr }
    : FuncDecl { $1}
    | FuncDef { $1 }
    | DataDefinition { $1 }

-- | The part that prefixes both function
-- declarations *and* definitions
-- TODO: abstract `small_id` and `operator` to one.
FuncOpener :: { Ident }
    : func small_id { $2 }
    | func "(" operator ")" { $3 }

FuncDecl :: { TopLevelExpr }
    : FuncOpener SigWithSemi { FuncDecl $1 $2 }

FuncDef :: { TopLevelExpr }
    : FuncOpener Params StmtAssignment { FuncDef $1 $2 $3 }

Signature :: { Type }
    : ":" Type { $2 }

-- | A type-signature that ends with a semicolon
SigWithSemi :: { Type }
    : Signature ";" { $1 }

Params :: { Params }
    : Params_ { reverse $1}

Params_ :: { Params }
    : Params_ Pattern { ($2:$1) }
    | Pattern { [$1] }

Pattern :: { Pattern }
    : small_id { Param $1 }
    | big_id { CtorPtrn $1 [] }
    | "(" big_id Params ")" { CtorPtrn $2 $3 }
    | "(" Pattern ")" { $2 }

Stmt :: { Expr }
    : Expr ";" { $1 }

StmtAssignment :: { Expr }
    : "=" Stmt { $2 }

Implication :: { Expr }
    : "=>" Expr { $2 }

Expr :: { Expr }
    : Term { $1 }
    | Term Signature { TypedExpr $1 $2 }
    | "\\" Params Implication { Lambda $2 $3 }
    | match Term "{" MatchCases "}" { Match $2 $4 }
    | FuncApp { FuncApp $1 }

Term :: { Expr }
    : small_id { VarExpr $1 }
    | big_id { VarExpr $1 }
    | integer { LitExpr (IntLit $1) }
    | float { LitExpr (FloatLit $1) }
    | char { LitExpr (CharLit $1) }
    | string { LitExpr (StringLit (toStrict $1)) }
    | operator { VarExpr $1 }
    -- | "(" operator ")" { VarExpr $2 }
    | "(" Expr ")" { $2 }

FuncApp :: { [Expr] }
    : FuncApp_ { reverse $1 }

FuncApp_ :: { [Expr] }
    : FuncApp_ Term { ($2:$1) }
    -- | FuncApp_ operator { (VarExpr $2:$1) }
    | Term Term { [$2, $1] } -- backwards bc it gets reversed

MatchCases :: { [Case] }
    : MatchCases MatchCase { ($2:$1) }
    | MatchCase { [$1] }

MatchCase :: { Case }
    : Pattern Implication ";" { Case $1 $2 }

Type :: { Type }
    : big_id Types0 { TypeCon $1 $2 }
    | Type "->" Type { $1 :-> $3 }
    | "(" Type ")" { $2 }

Types0 :: { [Type] }
    : Types0_ { reverse $1 }

Types0_ :: { [Type] }
    : Types0_ Type { ($2:$1) }
    | {- EMPTY -} { [] }

DataDefinition :: { TopLevelExpr }
    : data big_id "{" Constructors "}" { DataDef $2 $4 }

-- Order does not matter, so there is no need to use `@reverse@`
Constructors :: { [Constructor] }
    : Constructors Constructor { ($2:$1) }
    | {- EMPTY -} { [] }

Constructor :: { Constructor }
    : big_id SigWithSemi { Constructor $1 $2 }
    | big_id ";" { Nullary $1 }


{
parseError :: Token -> Alex a
parseError tok = lexError $ pretty "Unexpected token:" <+> pretty tok

parse :: ByteString -> ModuleName -> FilePath -> Either String ModuleAST
parse src mdl path = runLexer src mdl path blossomParser

parseFile :: FilePath -> ModuleName -> IO (Either String ModuleAST)
parseFile path mdl = do
    contents <- BS.readFile path
    -- the strictness of `contents` is important here!
    let result = parse (contents `seq` contents) mdl path
    return result
}
