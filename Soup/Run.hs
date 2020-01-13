module Soup.Run (
    parseStr,
    parseStr',
    runStr,
    debugFile,
) where

import Soup.Bootstrap
import Soup.Debugger
import Soup.Env
import Soup.Eval
import Soup.Parse
import Soup.Parser
import Soup.Value

import Control.Monad.Except
import Control.Monad.Identity
import Control.Monad.State

import System.IO

runEval :: (Env, DebugZipper) -> Eval a -> Either (InterpError, DebugTree) (a, DebugTree, Env)
runEval (initEnv, initDebug) x = case unwrapped of
    (Right x, (env, debugZip))  -> Right (x, rootTree debugZip, env)
    (Left err, (env, debugZip)) -> Left (err, rootTree debugZip)
    where
        unwrapped = runIdentity (runStateT (runExceptT (unwrapEval x))
                                           (initEnv, initDebug))

showDebugTree t@(Tree (_, program) _) = showEntry 0 [t] where
    showEntry k [t@(Tree (n, p) children)] = showInline n p ++ showEntry k (reverse children)
    showEntry k ts = concat $ map (showFull $ k + 1) ts

    showFull k (Tree (n, p) children) =
        indent k ++ showInline n p ++ showEntry k (reverse children)
    -- showInline n p = n ++ "(" ++ (show $ lineno p) ++ ") "
    showInline n p = n ++ " "

    indent k = "\n" ++ (concat $ replicate k "| ")
    lineno p = nlines program - nlines p + 1
    nlines = length . lines

parseStr' :: String -> Either (InterpError, DebugTree) ([Value], DebugTree, Env)
parseStr' s = runEval (emptyEnv, emptyTree ("ROOT", s)) $ do
    t <- initType
    parsing <- parse s [(t, contToVal "final-continuation" finalContinuation)]
    case parsing of
        [ListVal l] -> return l
        []          -> throwError ParsingError
        _           -> undefined

finalContinuation :: Value -> String -> Eval [Value]
finalContinuation v s = case s of
    "" -> logParser "SUCCESS" "" >> return [v]
    _  -> return []

parseStr :: String -> Either (InterpError, DebugTree) [Value]
parseStr s = do
    (val, _, _) <- parseStr' s
    return val

runStr :: String -> Either (InterpError, DebugTree) Value
runStr s = do
    (exprs, tree, env) <- parseStr' s
    (vals, _, _) <- runEval (env, emptyTree ("run-root", "")) $ mapM eval exprs
    return $ last vals

debugFile :: String -> IO ()
debugFile fname = do
    file <- readFile fname
    case parseStr' file of
        Right (vals, tree, env) -> do
            print vals
            showTree tree
        Left (err, tree) -> do
            putStrLn $ "Error: " ++ show err
            showTree tree
    where
        showTree tree = do
            putStrLn "=== DEBUG OUTPUT ==="
            putStrLn $ showDebugTree tree
